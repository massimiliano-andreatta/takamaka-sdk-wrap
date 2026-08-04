# FCM token deletion — `deletefcmtoken` and `deleteallfcmtokens`

Two new routes on the chat server, live on the test environment since **2026-08-04**.
They give the client a way to *remove* a push-token registration, where before it could
only disable one.

**If you read only one thing:** on an identity switch, call **`deletefcmtoken`** for the
outgoing identity instead of `unregisterfcmtoken`. That one change fixes the "push stops
working after switching identity" outage.

| | |
|---|---|
| Test server | `rschat-test01` — `wss://rschat-test.takamaka.org/rschat` |
| Firebase project | `fluttertakiapp` |
| SDK | `takamaka_sdk_wrap`, branch `feature/user-notifications` |
| Server build | `rschat-0.8.2-SNAPSHOT`, manifest `1.4` |

---

## 1. Why these exist

The server stores push tokens in a table whose **primary key is the hash of the FCM token
alone** — not (identity, token). One physical device has one FCM token, shared by every
identity in the app.

`unregisterfcmtoken` is a *soft* delete: it sets `is_active = false` and **leaves the row
in place** for up to 30 days, until a cleanup sweep collects it.

Put those two facts together and you get the outage:

```
identity A logs out   -> unregisterfcmtoken  -> row still there, is_active = false
identity B logs in    -> registerfcmtoken    -> INSERT fails: duplicate primary key
                                                (the row belongs to A)
result: the device has ZERO active tokens and receives NOTHING
```

This was reproduced on the server on 2026-08-03: an unregister at 20:03:10 followed by a
failed registration at 20:03:12, leaving the device with no active token.

A hard delete removes the row, so the next identity's registration inserts cleanly.

> Note this also explains why the old chat app never suffered the outage: it never called
> unregister at all, so identity A's working row simply stayed and kept receiving.

## 2. The four routes

| Route | Effect | Use it when |
|---|---|---|
| `registerfcmtoken` | Create or refresh this device's token | Login, token refresh, cold start |
| `unregisterfcmtoken` | Soft: `is_active = false`, row kept | Pausing pushes but keeping the registration |
| **`deletefcmtoken`** | **Hard: removes this device's row** | **Identity switch, logout** |
| **`deleteallfcmtokens`** | **Hard: removes every row of this identity** | "Stop pushing to all my devices" |

`unregisterfcmtoken` is unchanged — nothing you have today breaks.

All four take the **same envelope and the same `message_type`**. The route is what decides
the operation; the payload does not change.

## 3. Wire format

Identical to the registration request you already send. Message type stays
`FCM_TOKEN_REGISTRATION` for all four routes.

```json
{
  "from": "<your Ed25519 public key, base64url>",
  "signature": "<Ed25519 signature, base64url>",
  "message_type": "FCM_TOKEN_REGISTRATION",
  "signature_type": "Ed25519BC",
  "fcm_token_registration_signed_content": {
    "nonce":     { "nonce": "...", "timestamp": 1785..., "liveness": 300000 },
    "fcm_token": "<the device token>",
    "platform":  "android",
    "device_id": null
  }
}
```

The signature is Ed25519 over the **JCS / RFC 8785 canonical JSON of the
`fcm_token_registration_signed_content` object only** — not the whole envelope. `device_id`
must always be present, `null` included; dropping the key when null breaks verification.

Nothing here is new: if registration works today, deletion works with the same code.

### `deleteallfcmtokens` and the token field

Rows are selected by the signing identity (`from`) alone. `fcm_token` is **not used** and
may be an empty string — you do not need to still hold a live device token to log out
everywhere. The empty value is signed like any other and verifies normally.

### Scope guarantee

Both routes are scoped to the signing identity. An identity can only ever remove **its
own** rows, even when two identities share one device token. There is no way to delete
someone else's registration.

## 4. Nonces are now single-use — on all four routes

**This is the one behavioural change that affects code you already have.**

Fetch a fresh nonce for **every** FCM call and never cache or reuse one. The server now
spends the nonce on first use, on `registerfcmtoken` and `unregisterfcmtoken` too. A second
use of the same nonce answers `NONCE_INVALID` — including a retry of a call that already
reached the server. On retry, fetch a new nonce and re-sign.

Why: the signature covers only the signed *content*, not `message_type` and not the route,
so an identical envelope is valid at all four routes. Without single-use nonces, anyone who
observed a registration could resend those exact bytes at `deleteallfcmtokens` and switch a
user's push off. Spending the nonce makes the captured copy worthless.

We checked the shipped app before making this change: it holds no nonce state, so it should
already be fetching one per call and this should be transparent for you. If you do see
`NONCE_INVALID`, that is the cause and the fix is to move the `getNonce()` inside the call.

## 5. Response

Deletion answers a **row count**, not a registration time:

```json
{ "success": true, "message": "FCM token(s) deleted successfully",
  "error_code": null, "deleted_count": 1 }
```

**Deletion is idempotent.** Deleting something that is not registered is a *success* with
`deleted_count: 0`, not an error — you never have to special-case a retry. Read
`deleted_count` if you want to distinguish "removed" from "was not there".

(For contrast, `unregisterfcmtoken` still answers `TOKEN_NOT_FOUND` in that case.)

### Error codes

| `error_code` | Cause | What to do |
|---|---|---|
| `NONCE_INVALID` | Nonce unknown, expired or already spent | Fetch a fresh nonce, re-sign. Never retry with the old one |
| `SIGNATURE_ERROR` | Canonical/signature mismatch | Bug — check `device_id: null` is present |
| `VALIDATION_ERROR` | Missing signed content, or nonce is not a UUID | Bug |
| `RATE_LIMIT_EXCEEDED` | ACCOUNT bucket, 20 burst / 60 per minute | Back off and retry later |
| `DELETION_ERROR` | Server-side failure | Retry once with a new nonce, then surface |

## 6. Using it from the SDK

```dart
// Identity switch — delete the outgoing identity's registration,
// then register the incoming one.
await chatApi.deleteFcmToken(
  keys: outgoingKeys,                 // sign BEFORE discarding the keys
  nonce: await chatApi.getNonce(),    // fresh nonce, every call
  fcmToken: token,
  platform: platform,                 // 'android' | 'ios'
  deviceId: null,
);

await chatApi.registerFcmToken(
  keys: incomingKeys,
  nonce: await chatApi.getNonce(),    // a second fresh nonce
  fcmToken: token,
  platform: platform,
  deviceId: null,
);
```

```dart
// Log out of push on every device of this identity.
// fcmToken defaults to '' — the server ignores it here.
await chatApi.deleteAllFcmTokens(
  keys: keys,
  nonce: await chatApi.getNonce(),
);
```

Both must be signed **before** the identity's keys are discarded.

## 7. Recommended lifecycle

1. Login / identity unlock → subscribe to `notification`, then `registerFcmToken`.
2. `onTokenRefresh` → `registerFcmToken` again (idempotent, updates in place).
3. **Identity switch → `deleteFcmToken` for the old identity, then `registerFcmToken` for
   the new one.** Do not use `unregisterFcmToken` here.
4. Logout → `deleteFcmToken`, or `deleteAllFcmTokens` to clear every device.
5. Uninstall → nothing to do; the server deactivates tokens that FCM reports as
   `UNREGISTERED`.

## 8. Checking the server supports them

The routes are advertised in the public `serverinfo` manifest (version `1.4`), which needs
no nonce and no signature:

```
supportedRoutes: [ ..., deleteallfcmtokens, deletefcmtoken, deletemessage, ... ]
```

If `supportedRoutes` is present and does not list them, the server is older — fall back to
`unregisterfcmtoken`. If the field is empty or absent, the server cannot report its routes;
just try the call.

## 9. What is still open on our side

Two identities on one device still cannot hold the same FCM token **at the same time** —
the primary key allows only one. Deleting before registering works because the two never
overlap. Supporting genuinely simultaneous multi-identity push needs a schema and privacy
decision on our side (a composite key would make the two identities linkable), and is
tracked separately. It does not block anything described here.
