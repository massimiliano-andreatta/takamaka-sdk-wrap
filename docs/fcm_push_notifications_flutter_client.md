# Push notifications on a Flutter client — implementation guide

Audience: the developer of `flutter_base`, integrating rschat push notifications
using `takamaka_sdk_wrap`.

Server this describes: **rschat `integration/delete-retention-fcm` @ 0827c47**
with **messages @ 95f0ec1** — the newest server branch, carrying the FCM work
plus DR-025 (delete for everyone) and DR-026 (retention). The FCM classes
(`FcmService`, `NotificationService`) are byte-identical to `feature/user-notifications`
@ 80b02b4, which is the build the flows below were verified against on a live
device on 2026-07-28.

---

## 1. What the server actually sends you

The push is **data-only and zero-knowledge**. It carries no message text, no
contact name, no conversation title — the server does not have them in clear and
would not be allowed to relay them if it did. What arrives is a *sync trigger*:

```json
{
  "type": "NEW_MESSAGE",
  "timestamp": "1785235508343",
  "conversation_hash": "bc7c0cc1328013cfbb7883a620a864e1e05a2366577c4a97a9b2f2bf02886bda",
  "sender_pk": "60RGUEm8pSAWCplx3EJWcdf5-r766VL9qE88qikUCQk.",
  "v": "1"
}
```

Built in `FcmService.buildFcmMessageBody`. Notes that matter:

- `v` is the payload version (currently `"1"`), not `version`.
- `conversation_hash` and `sender_pk` are omitted when the server has no value,
  so treat both as nullable.
- `timestamp` is a **string** holding epoch milliseconds.
- Android gets `"android": {"priority": "high"}` and nothing else — no
  `notification` block, so **Android displays nothing unless your client builds
  the notification itself**.
- iOS additionally gets an APNs `alert` with a generic title plus
  `mutable-content: 1` and `apns-push-type: alert`, `apns-priority: 10`. This is
  deliberate: a pure `content-available` silent push is throttled by iOS and is
  not reliably delivered. See §8.

### Notification types

`NOTIFICATION_TYPES` (messages `io.takamaka.messages.utils`):

| Type | Meaning | What the client should do |
|---|---|---|
| `NEW_MESSAGE` | New message in a conversation | Sync, show a banner |
| `QUOTE_IN_CONVERSATION` | Someone quoted/replied to you | Sync, show a banner |
| `MESSAGE_DELETED` | DR-025 delete-for-everyone fan-out | Sync **silently** — a "New message" banner for a deletion is actively wrong |
| `CONVERSATION_REQUEST` | New conversation offered | Sync; banner is a product decision |
| `SETTINGS_UPDATE` | Settings changed elsewhere | Sync silently |

Treat unknown types as **silent sync**, so the client degrades gracefully as the
server adds types. The value on the wire is the Java enum `name()` — uppercase.

Note that DR-026 retention expiry is intentionally silent: a message ageing out
must never produce a push.

---

## 2. The mistake to avoid: the presence model

**Read this before writing any code.** It is the single biggest trap, and an
existing client (tkmChat) fell into it.

The server decides between "deliver in-band" and "send a push" in
`NotificationService.publishToSinks`:

```java
Sinks.Many<UserNotificationJsonBean> userSink = userNotificationSinks.get(receiverPK);
if (userSink != null) {           // ONLINE  → in-band, no push
    userSink.tryEmitNext(...);
} else if (receiverPK.equals(undbb.getSenderKey())) {
    // sender's own message → no push (see §7)
} else {                          // OFFLINE → FCM push
    fcmService.sendNotificationToUser(...);
}
```

`userNotificationSinks` is populated **only** by the `notification` route. It is
*not* populated by `retrievemessages`.

So a client that subscribes only to `retrievemessages` — which is enough to
receive messages and looks perfectly healthy — is permanently classified
**offline**. Consequences observed live:

- every message is delivered in-band **and** pushed (127 ms apart), so the user
  gets a duplicate notification for a message they are already reading;
- push volume equals total message volume, all of it routed through Google;
- the server-side "drop the sink when the client disconnects" behaviour can
  never be exercised, because no sink is ever created.

Confirmed with the server's own 5-minute sweep, with both a compliant client and
tkmChat connected:

```
SinkCleanupTask: Active notification sinks: 3, Active message sinks: 5
```

**Requirement: subscribe to the `notification` stream for every identity you
want push behaviour to be correct for, and keep it open for the lifetime of the
session.** Presence *is* that subscription. The SDK call:

```dart
final sub = chatApi.subscribeNotifications(
  keys: keys,
  notBefore: 0,      // 0 = from the beginning
  onlyUnread: false,
).listen(handleNotification, onError: ..., cancelOnError: false);
```

Cancel it on logout/identity switch; the server drops the sink on the terminal
signal, which is what flips you to "offline" and makes pushes start arriving.

---

## 3. Registration protocol

### Signing contract

Every signed chat request to rschat is an **Ed25519** signature (`Ed25519BC`)
over the **JCS / RFC 8785 canonical JSON of the signed *content* sub-object** —
not the whole envelope.

Envelope:

```json
{
  "from": "<signing public key, url-base64>",
  "signature": "<url-base64>",
  "message_type": "FCM_TOKEN_REGISTRATION",
  "signature_type": "Ed25519BC",
  "fcm_token_registration_signed_content": { ...content... }
}
```

Content (this is what gets canonicalised and signed):

```json
{
  "nonce":      { "nonce": "...", "timestamp": 1700000000000, "liveness": 60000 },
  "fcm_token":  "<FCM registration token>",
  "platform":   "android",
  "device_id":  null
}
```

`nonce` is the **entire object** returned by the `nonce` route, embedded verbatim.
`platform` must be one of `android`, `ios`, `web`.

### The `device_id` pitfall

> **`device_id` must always be present, including when null.** Write
> `"device_id": null` — never omit the key.

The server's signed-content bean is a Lombok `@Data` class with no
`@JsonInclude(NON_NULL)`, so it canonicalises to
`{"device_id":null,"fcm_token":...}`. A client that drops the key signs
different bytes than the server reconstructs, and verification fails with
`SIGNATURE_ERROR` on exactly the common case of an unset device id.

This is locked down by cross-language golden vectors — messages
`FcmCanonicalVectorTest` (Java) and `test/tkm_chat_fcm_registration_test.dart`
(Dart) assert the identical strings:

```
{"device_id":null,"fcm_token":"fixed-fcm-token-XYZ","nonce":{"liveness":60000,"nonce":"11111111-2222-3333-4444-555555555555","timestamp":1700000000000},"platform":"android"}
```

If you build the request yourself rather than via the SDK, run your output
against those vectors before debugging anything else.

### Routes

| Route | Purpose |
|---|---|
| `nonce` | Fetch a fresh nonce (request-response) |
| `registerfcmtoken` | Register/refresh this device's token |
| `unregisterfcmtoken` | Soft-delete: clears `is_active`, keeps the row |
| `deletefcmtoken` | **Hard delete** of this device's row (identity switch) |
| `deleteallfcmtokens` | **Hard delete** of every row of the signing identity |
| `notification` | **Live notification stream — this is presence** |
| `notificationhistory` | Buffered history |

All four carry the **same** `message_type` (`FCM_TOKEN_REGISTRATION`) and the
same content shape; only the route differs.

**Soft vs hard delete — pick the right one.** `unregisterfcmtoken` only flips
`is_active` and leaves the row until the 30-day sweep. The server keys that
table on the **token hash alone**, so a leftover row makes the *next* identity's
registration of the same device token fail with a duplicate-key error, and the
device then silently receives nothing. So:

- **identity switch / logout on a device that keeps running** → `deletefcmtoken`;
- **"stop pushing to all my devices"** → `deleteallfcmtokens`;
- `unregisterfcmtoken` remains for pausing pushes while keeping the row.

**Every one of the four routes consumes the nonce.** Fetch a fresh one per call
and never cache or reuse one; a second use answers `NONCE_INVALID`, including a
retry of a call that already reached the server. This is what stops a captured
envelope being re-aimed: the signature covers only the signed *content*, not
`message_type` and not the route, so identical bytes are valid at all four —
without single-use nonces, an observed registration could be resent verbatim at
`deleteallfcmtokens` to switch a user's push off. Spending the nonce on first
use makes the captured copy worthless.

The delete routes are additionally scoped to the signing identity — they can
never remove another identity's rows, including on a shared device — and both
are idempotent, answering `deleted_count: 0` rather than an error when nothing
matched. `deleteallfcmtokens` ignores the signed `fcm_token`, so a caller that
no longer holds a device token may sign a blank one.

### Response and error codes

```json
{ "success": true, "message": null, "error_code": null, "registration_time": 1785235508343 }
```

The delete routes answer a different shape — a row count instead of a
registration time:

```json
{ "success": true, "message": "FCM token(s) deleted successfully", "error_code": null, "deleted_count": 1 }
```

| `error_code` | Cause | Client action |
|---|---|---|
| `RATE_LIMIT_EXCEEDED` | Too many requests (ACCOUNT bucket) | Back off and retry later |
| `SIGNATURE_ERROR` | Canonical/signature mismatch | Bug — check `device_id`, see above |
| `INVALID_USER` / `INVALID_TOKEN` | Empty public key or token | Bug |
| `INVALID_PLATFORM` | Not android/ios/web | Bug |
| `TOKEN_LIMIT_EXCEEDED` | User at `max-tokens-per-user` (default 10) | Prompt to unregister old devices |
| `REGISTRATION_ERROR` | Server-side failure | Retry once, then surface |
| `NONCE_INVALID` | Nonce unknown, expired or already spent — **any** route | Fetch a fresh nonce and re-sign; never retry with the old one |
| `VALIDATION_ERROR` | Missing signed content, or a nonce that is not a UUID | Bug |
| `UNREGISTRATION_ERROR` / `DELETION_ERROR` | Server-side failure | Retry once **with a new nonce**, then surface |

Server-side, tokens inactive for `stale-token-days` (default 30) are swept, and
tokens FCM reports as unregistered/invalid (HTTP 404 `UNREGISTERED`, or 400
`INVALID_ARGUMENT` naming the token) are deactivated automatically. Transient
failures (401/403/429/5xx) keep the token.

---

## 4. Client implementation

### Dependencies

```yaml
dependencies:
  firebase_core: ^…
  firebase_messaging: ^…
  flutter_local_notifications: ^…   # required — the payload is data-only
```

Then `flutterfire configure` to generate `firebase_options.dart` and
`android/app/google-services.json`, and apply the Google services Gradle plugin.

### Startup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(...);
}
```

Guard repeat initialisation with `if (Firebase.apps.isEmpty)` if any other code
path may also initialise Firebase.

### Registering after login

```dart
final nonce = await chatApi.getNonce();

final response = await chatApi.registerFcmToken(
  keys: keys,
  nonce: nonce,
  fcmToken: await FirebaseMessaging.instance.getToken() ?? '',
  platform: Platform.isIOS ? 'ios' : 'android',
  deviceId: null,           // fine — the SDK sends "device_id": null correctly
);

if (response['success'] != true) {
  // inspect response['error_code'] per the table above
}
```

Do this **after** the identity's keys are available and the transport is
connected. Also re-register:

- on `FirebaseMessaging.instance.onTokenRefresh` (tokens rotate);
- on every cold start, since a token can change while the app is closed.

Registration is idempotent: an existing (user, token) pair is updated rather
than duplicated. The *nonce* is not — each call needs its own
`await chatApi.getNonce()`. Re-registering on token refresh or cold start is
fine; re-sending the same signed envelope is not.

### Unregistering on logout

```dart
await chatApi.unregisterFcmToken(
  keys: keys, nonce: await chatApi.getNonce(),
  fcmToken: token, platform: platform, deviceId: null,
);
```

Call it **before** discarding the identity's keys — the request must be signed.

### Foreground handler

```dart
FirebaseMessaging.onMessage.listen((message) async {
  final data = message.data;
  final type = (data['type'] as String?)?.toUpperCase();
  final conversationHash = data['conversation_hash'] as String?;
  if (conversationHash == null || conversationHash.isEmpty) return;

  // 1. Always sync — the push carries no content.
  await syncConversation(conversationHash);

  // 2. Banner only for message-bearing types…
  if (type != 'NEW_MESSAGE' && type != 'QUOTE_IN_CONVERSATION') return;

  // 3. …and not for the conversation the user is currently reading.
  if (conversationHash == currentlyOpenConversationHash) return;

  await showLocalNotification(conversationHash, data['sender_pk'] as String?);
});
```

`onMessage` fires **only in the foreground**, so no lifecycle check is needed —
if this handler runs, the app is on screen.

Whether to banner messages for *other* conversations while the app is open is a
product decision: current tkmChat behaviour banners them; an in-app cue (unread
badge / toast) is the more common alternative.

### Background handler

Must be a top-level function annotated `@pragma('vm:entry-point')`. It runs in
its **own isolate**: no Riverpod providers, no open database, no unlocked
wallet.

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = (message.data['type'] as String?)?.toUpperCase();
  if (type != 'NEW_MESSAGE' && type != 'QUOTE_IN_CONVERSATION') return;

  final conversationHash = message.data['conversation_hash'] as String?;
  if (conversationHash == null || conversationHash.isEmpty) return;

  await showLocalNotification(conversationHash, null);   // generic label
}
```

Without this, a closed app shows **nothing at all** until next launch, which
defeats the feature. Because the isolate cannot open the encrypted store, its
label must be generic — anything it needs (e.g. which identity is registered)
has to come from `SharedPreferences`, which *is* readable there.

### Labels and the zero-knowledge rule

The server never sends display names. Resolve them **on device only**:

- a contact name from local storage if you have one;
- otherwise a truncated key.

**Never route a display name through the server so it can be echoed back in a
payload** — that would hand the server (and Google) the social graph in clear
and destroy the zero-knowledge property.

Useful in practice: include the **addressed identity** in the banner
(`New message · to t8oUddbEJ8M…`). On a multi-identity device "which of my
addresses is this for?" is not answerable from the sender alone.

### Android channel

Create a high-importance channel up front. On Android 8+ importance is fixed at
channel-creation time, so a channel first created at low importance stays silent
even after you change the constant.

Use a stable notification id derived from the conversation hash so a busy chat
replaces rather than stacks, and cancel it when the user opens that chat.

---

## 5. Putting it together — the lifecycle

1. App start → `Firebase.initializeApp`, register background handler.
2. Login / identity unlock → connect transport → **subscribe to `notification`** (§2).
3. Request notification permission → get token → `registerFcmToken` (§3).
4. `onTokenRefresh` → re-register.
5. Foreground: `notification` stream delivers events in-band; pushes should be rare.
6. Backgrounded / killed: server sees no sink → push arrives → background isolate renders the banner.
7. Tap → open the conversation (`onMessageOpenedApp`, plus `getInitialMessage()` for a cold start from a tap).
8. Identity switch → `deleteFcmToken` for the outgoing identity, then register
   the incoming one. Do **not** use `unregisterFcmToken` here: it leaves the row
   and the re-registration fails on the token-hash primary key (see §3).
9. Logout → `deleteFcmToken` (or `deleteAllFcmTokens` to clear every device),
   then cancel the notification subscription. Sign it **before** discarding the
   identity's keys.

---

## 6. Testing without a second device

You can send a push shaped exactly like the server's using the Firebase service
account, which is much faster than orchestrating two chat clients:

1. Sign an RS256 JWT with the service-account key (`openssl dgst -sha256 -sign`).
2. Exchange it at `https://oauth2.googleapis.com/token` for an access token.
3. `POST https://fcm.googleapis.com/v1/projects/<project>/messages:send` with the
   data-only body from §1.

The whole thing is ~30 lines of shell; the only fiddly part is base64url
(`openssl base64 -A | tr '+/' '-_' | tr -d '='`) and remembering to delete the
extracted private key afterwards.

Reading the result on an emulator:

```bash
adb logcat -d | grep -iE "message received|Notification: type="
adb shell dumpsys notification --noredact | grep -A40 "io.takamaka.tkm_chat" | grep android.text
```

### Running rschat locally with FCM on

```bash
FCM_ENABLED=true \
FCM_PROJECT_ID=<firebase-project> \
FCM_CREDENTIALS_PATH=/path/to/service-account.json \
mvn spring-boot:run -Dspring-boot.run.profiles=localhost
```

Alternatively `FCM_CREDENTIALS_JSON` with the JSON inline. With
`FCM_ENABLED=false`, `registerToken` returns **success without storing
anything** and no push is ever sent — an easy way to spend an hour debugging a
client that is actually fine.

### The client and the server must be on the same Firebase project

A registration token is only meaningful to the project that minted it. If your
`google-services.json` / `GoogleService-Info.plist` names one project and the
server's service-account credential names another, registration succeeds, the
token persists, and **every push fails** — the server logs a dispatch and FCM
answers `UNREGISTERED`, which deactivates the row. Nothing in the client's logs
says why.

The test server (`rschat-test01`) runs against **`fluttertakiapp`** as of
2026-08-03, moved off the throwaway `takamaka-chat-test` project. Build against
that project, and re-run `flutterfire configure` if you were previously pointed
elsewhere.

Two failure modes worth separating when a send breaks:

- `403 PERMISSION_DENIED` — the service account lacks
  `cloudmessaging.messages.create`. Grant *Firebase Cloud Messaging API Admin*
  to the `firebase-adminsdk-…` account **named in the key file**; granting it to
  the Google-managed `service-<num>@gcp-sa-firebase` account does nothing. A
  freshly created project trips this every time.
- `400 INVALID_ARGUMENT` naming `message.token` — credentials and IAM are fine,
  the token is simply stale or from another project.

You can tell these apart before touching a server: sign an RS256 JWT with the
service-account key, exchange it at `oauth2.googleapis.com`, then POST to
`messages:send` with `"validate_only": true` and a deliberately invalid token.
A 400 about the token means auth and IAM are good; a 403 means they are not.
Nothing is delivered either way.

The schema is **applied manually**: run `420-fcm-tokens.sql` against the
database before enabling FCM.

Log lines worth grepping, one per branch of §2:

```
Published notification to user: <pk>                       # online, in-band
User <pk> offline, FCM push dispatched                     # offline branch
FCM push dispatched to offline user <pk> (1 token(s))      # sent to Google OK
Skipping FCM self-push for <pk> (sender == receiver)       # DEBUG level only
```

The self-push line is `log.debug`, invisible at the default INFO root level. Run
with `--logging.level.io.takamaka.rschat.service.NotificationService=DEBUG` or
the evidence never appears.

If the machine sits behind a TLS-intercepting proxy (e.g. corporate AV), the JVM
needs `-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT` or Google's OAuth endpoint
fails PKIX validation.

---

## 7. Behaviour you can rely on (verified live, 2026-07-28)

- **No self-push.** The sender is a member of the conversation and does get a
  notification *row* (multi-device sync), but no push is sent to them. Verified
  repeatedly against real traffic.
- **Online recipients are not pushed.** A recipient holding a `notification`
  sink is served in-band and FCM is not called.
- **Delivery is fast.** Dispatch → device was ~180 ms locally; server → Google →
  device was 1–2 s against the public test server.
- **Closed apps still get banners**, via the background isolate.

---

## 8. Platform notes

**Android.** Needs Google Play services. On an emulator, FCM `getToken()`
returns null with `AUTHENTICATION_FAILED` unless a Google account is signed in
(Settings → Accounts).

**iOS.** Not yet exercised end to end. You will need:

- an APNs auth key (`.p8`) uploaded to Firebase, with its Key ID and the team's
  10-character Team ID. Reported uploaded by the flutter_base developer on
  2026-08-03 — **not verified from our side.** It has to land on the *same*
  project the server uses (see §6); an APNs key on the wrong project fails
  silently, with iOS simply never receiving anything.
- Push Notifications capability, Background Modes → Remote notifications, and
  the `aps-environment` entitlement on the iOS target;
- a **Notification Service Extension** (native Swift). The payload is
  zero-knowledge, so the extension is what decrypts locally and rewrites the
  banner into something meaningful. `mutable-content: 1` (already sent) is what
  wakes it. Still outstanding.

The `.p8` is a high-value credential: unless it was created restricted to a
single topic, one key can push to every app in the team, in both sandbox and
production, and it never expires. Keep it in the password manager, never in a
repo, and revoke via developer.apple.com → Keys if it is ever sent over an
unencrypted channel.

Do not switch iOS to a pure silent `content-available` push — it is throttled
and unreliable, which is exactly why the server sends a generic alert instead.

---

## 9. Known issues — read before designing your identity handling

### Multi-identity: only the first identity on a device can register

A device has **one** FCM token, but `user_fcm_tokens` uses `token_hash` as its
**sole primary key**. `FcmService.registerToken` looks the row up by
*(user, token)*, so a second identity on the same device misses the lookup,
takes the insert branch, and collides:

```
Error registering FCM token for user 1Jd2hg9g82EpUigp…:
  duplicate key value violates unique constraint "user_fcm_tokens_pkey"
```

The error escapes the service's own handler at transaction-commit time and
reaches the client as **`RS-513 … ROLLBACK`**, not a clean `REGISTRATION_ERROR`.

**Client guidance today: register the token for the active identity only**, and
treat a registration failure for a secondary identity as expected rather than
fatal.

Do **not** assume this will be fixed by making the primary key composite
`(user_public_key, token_hash)`. That would let one device register the same
token under two identities, creating exactly the cross-identity linkage the
threat model warns about — visible to both the rschat database and Google. The
current key accidentally enforces one identity per device. The real options are:
accept one identity per device for push, accept the linkage, or register only
the active identity. **It is an open policy decision.**

Corollary: any "addressed identity" you show in a banner is only truthful while
that constraint holds.

### Ghost identities must not register

Ghost identities must never register an FCM token. The server would accept it;
the restriction is **client-enforced**. Add the guard before ghost keys reach
the registration path.

### Duplicate notifications

Covered in §2 — subscribe to the `notification` stream. If you skip it, expect a
push for every message plus the in-band copy.

---

## 10. Quick reference

| Thing | Value |
|---|---|
| Message type (register, unregister **and** both deletes) | `FCM_TOKEN_REGISTRATION` |
| Signature type | `Ed25519BC` |
| Signed content key | `fcm_token_registration_signed_content` |
| Canonicalisation | JCS / RFC 8785, over the **content**, not the envelope |
| `device_id` when unknown | `null` — key present, never omitted |
| Payload version key | `v` (currently `"1"`) |
| Payload keys | `type`, `timestamp`, `conversation_hash`, `sender_pk`, `v` |
| Presence source | the `notification` request-stream — nothing else |
| Test server | `wss://rschat-test.takamaka.org/rschat` (`TkmChatEnumEnvironments.test`) |
| Firebase project (test) | `fluttertakiapp` — client and server must match, see §6 |
| Production | `wss://rschat.takamaka.org/rschat` (`TkmChatEnumEnvironments.production`) |

SDK entry points (`TkmChatClientApi`):

```dart
Future<Map<String, dynamic>> getNonce();
Stream<Map<String, dynamic>> subscribeNotifications({keys, notBefore, onlyUnread});
Stream<Map<String, dynamic>> retrieveNotificationHistory({keys, notBefore, onlyUnread});
Future<Map<String, dynamic>> registerFcmToken({keys, nonce, fcmToken, platform, deviceId});
Future<Map<String, dynamic>> unregisterFcmToken({keys, nonce, fcmToken, platform, deviceId});
Future<Map<String, dynamic>> deleteFcmToken({keys, nonce, fcmToken, platform, deviceId});
Future<Map<String, dynamic>> deleteAllFcmTokens({keys, nonce, fcmToken = '', platform = 'android', deviceId});
```

The two delete calls need a **fresh nonce each time** — the server consumes it —
and answer `deleted_count` instead of `registration_time`.

Lower level, if you need the envelope without sending it:
`TkmChatCrypto.buildFcmTokenRegistrationRequest(keys:, nonceResponse:, fcmToken:, platform:, deviceId:)`.
