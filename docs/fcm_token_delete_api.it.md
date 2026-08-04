# Cancellazione dei token FCM — `deletefcmtoken` e `deleteallfcmtokens`

Due nuove route sul server di chat, attive sull'ambiente di test dal **2026-08-04**.
Danno al client un modo per *rimuovere* la registrazione di un token push, dove prima era
possibile solo disattivarla.

**Se leggi una cosa sola:** al cambio di identità chiama **`deletefcmtoken`** per l'identità
uscente invece di `unregisterfcmtoken`. Questa singola modifica risolve il problema delle
"push che smettono di funzionare dopo il cambio di identità".

| | |
|---|---|
| Server di test | `rschat-test01` — `wss://rschat-test.takamaka.org/rschat` |
| Progetto Firebase | `fluttertakiapp` |
| SDK | `takamaka_sdk_wrap`, branch `feature/user-notifications` |
| Build del server | `rschat-0.8.2-SNAPSHOT`, manifest `1.4` |

---

## 1. Perché servono

Il server salva i token push in una tabella la cui **chiave primaria è il solo hash del
token FCM** — non (identità, token). Un dispositivo fisico ha un solo token FCM, condiviso
da tutte le identità dell'app.

`unregisterfcmtoken` è una cancellazione *logica*: imposta `is_active = false` e **lascia la
riga al suo posto** fino a 30 giorni, finché non la raccoglie la pulizia periodica.

Mettendo insieme le due cose si ottiene il guasto:

```
l'identità A esce      -> unregisterfcmtoken  -> riga ancora presente, is_active = false
l'identità B entra     -> registerfcmtoken    -> INSERT fallisce: chiave primaria duplicata
                                                 (la riga appartiene ad A)
risultato: il dispositivo ha ZERO token attivi e non riceve NULLA
```

Riprodotto sul server il 2026-08-03: un'unregister alle 20:03:10 seguita da una
registrazione fallita alle 20:03:12, che ha lasciato il dispositivo senza alcun token attivo.

La cancellazione fisica rimuove la riga, così la registrazione dell'identità successiva
viene inserita senza conflitti.

> Questo spiega anche perché la vecchia app di chat non ha mai avuto il problema: non
> chiamava mai unregister, quindi la riga funzionante dell'identità A restava e continuava
> a ricevere.

## 2. Le quattro route

| Route | Effetto | Quando usarla |
|---|---|---|
| `registerfcmtoken` | Crea o aggiorna il token di questo dispositivo | Login, refresh del token, avvio a freddo |
| `unregisterfcmtoken` | Logica: `is_active = false`, riga mantenuta | Sospendere le push mantenendo la registrazione |
| **`deletefcmtoken`** | **Fisica: rimuove la riga di questo dispositivo** | **Cambio di identità, logout** |
| **`deleteallfcmtokens`** | **Fisica: rimuove tutte le righe di questa identità** | "Non inviare push a nessuno dei miei dispositivi" |

`unregisterfcmtoken` non è cambiata: nulla di ciò che hai oggi si rompe.

Tutte e quattro usano **lo stesso envelope e lo stesso `message_type`**. È la route a
decidere l'operazione; il payload non cambia.

## 3. Formato sul filo

Identico alla richiesta di registrazione che già invii. Il message type resta
`FCM_TOKEN_REGISTRATION` per tutte e quattro le route.

```json
{
  "from": "<la tua chiave pubblica Ed25519, base64url>",
  "signature": "<firma Ed25519, base64url>",
  "message_type": "FCM_TOKEN_REGISTRATION",
  "signature_type": "Ed25519BC",
  "fcm_token_registration_signed_content": {
    "nonce":     { "nonce": "...", "timestamp": 1785..., "liveness": 300000 },
    "fcm_token": "<il token del dispositivo>",
    "platform":  "android",
    "device_id": null
  }
}
```

La firma è Ed25519 sul **JSON canonico JCS / RFC 8785 del solo oggetto
`fcm_token_registration_signed_content`** — non dell'intero envelope. `device_id` deve
essere sempre presente, anche quando vale `null`: omettere la chiave se nulla rompe la
verifica.

Nulla di nuovo: se oggi la registrazione funziona, la cancellazione funziona con lo stesso
codice.

### `deleteallfcmtokens` e il campo del token

Le righe sono selezionate in base alla sola identità firmataria (`from`). `fcm_token`
**non viene usato** e può essere una stringa vuota: non serve avere ancora un token di
dispositivo valido per uscire da tutti i dispositivi. Il valore vuoto viene firmato come
qualsiasi altro e si verifica normalmente.

### Garanzia di ambito

Entrambe le route sono limitate all'identità firmataria. Un'identità può rimuovere solo le
**proprie** righe, anche quando due identità condividono lo stesso token di dispositivo.
Non c'è modo di cancellare la registrazione di qualcun altro.

## 4. I nonce sono ora monouso — su tutte e quattro le route

**Questa è l'unica modifica di comportamento che tocca codice che hai già.**

Richiedi un nonce nuovo per **ogni** chiamata FCM e non memorizzarlo né riutilizzarlo mai.
Il server ora lo consuma al primo utilizzo, anche su `registerfcmtoken` e
`unregisterfcmtoken`. Un secondo utilizzo dello stesso nonce risponde `NONCE_INVALID` —
incluso il retry di una chiamata già arrivata al server. In caso di retry, richiedi un
nuovo nonce e rifirma.

Il motivo: la firma copre solo il *contenuto* firmato, non `message_type` e non la route,
quindi un envelope identico è valido su tutte e quattro le route. Senza nonce monouso,
chiunque avesse osservato una registrazione avrebbe potuto rispedire quegli stessi byte a
`deleteallfcmtokens` e spegnere le push di un utente. Consumare il nonce rende inutile la
copia intercettata.

Abbiamo verificato l'app già distribuita prima di fare questa modifica: non conserva alcuno
stato relativo ai nonce, quindi dovrebbe già richiederne uno per chiamata e per te dovrebbe
essere trasparente. Se dovessi vedere `NONCE_INVALID`, la causa è questa e la correzione è
spostare la `getNonce()` dentro la chiamata.

## 5. Risposta

La cancellazione risponde con un **conteggio di righe**, non con un istante di
registrazione:

```json
{ "success": true, "message": "FCM token(s) deleted successfully",
  "error_code": null, "deleted_count": 1 }
```

**La cancellazione è idempotente.** Cancellare qualcosa che non è registrato è un
*successo* con `deleted_count: 0`, non un errore: non devi mai gestire il retry come caso
speciale. Leggi `deleted_count` se vuoi distinguere "rimosso" da "non c'era".

(Per confronto, `unregisterfcmtoken` in quel caso risponde ancora `TOKEN_NOT_FOUND`.)

### Codici di errore

| `error_code` | Causa | Cosa fare |
|---|---|---|
| `NONCE_INVALID` | Nonce sconosciuto, scaduto o già consumato | Richiedi un nonce nuovo e rifirma. Mai riprovare con quello vecchio |
| `SIGNATURE_ERROR` | Canonicalizzazione/firma non corrispondenti | Bug — verifica che `device_id: null` sia presente |
| `VALIDATION_ERROR` | Contenuto firmato mancante, o nonce non UUID | Bug |
| `RATE_LIMIT_EXCEEDED` | Bucket ACCOUNT, 20 di burst / 60 al minuto | Attendi e riprova più tardi |
| `DELETION_ERROR` | Errore lato server | Riprova una volta con un nuovo nonce, poi segnala |

## 6. Uso dallo SDK

```dart
// Cambio di identità — cancella la registrazione dell'identità uscente,
// poi registra quella entrante.
await chatApi.deleteFcmToken(
  keys: outgoingKeys,                 // firma PRIMA di scartare le chiavi
  nonce: await chatApi.getNonce(),    // nonce nuovo, a ogni chiamata
  fcmToken: token,
  platform: platform,                 // 'android' | 'ios'
  deviceId: null,
);

await chatApi.registerFcmToken(
  keys: incomingKeys,
  nonce: await chatApi.getNonce(),    // un secondo nonce nuovo
  fcmToken: token,
  platform: platform,
  deviceId: null,
);
```

```dart
// Disattiva le push su tutti i dispositivi di questa identità.
// fcmToken vale '' per default — qui il server lo ignora.
await chatApi.deleteAllFcmTokens(
  keys: keys,
  nonce: await chatApi.getNonce(),
);
```

Entrambe vanno firmate **prima** che le chiavi dell'identità vengano scartate.

## 7. Ciclo di vita consigliato

1. Login / sblocco identità → sottoscrivi `notification`, poi `registerFcmToken`.
2. `onTokenRefresh` → di nuovo `registerFcmToken` (idempotente, aggiorna sul posto).
3. **Cambio di identità → `deleteFcmToken` per la vecchia identità, poi `registerFcmToken`
   per la nuova.** Qui non usare `unregisterFcmToken`.
4. Logout → `deleteFcmToken`, oppure `deleteAllFcmTokens` per azzerare tutti i dispositivi.
5. Disinstallazione → nulla da fare; il server disattiva i token che FCM segnala come
   `UNREGISTERED`.

## 8. Verificare che il server le supporti

Le route sono pubblicate nel manifest pubblico `serverinfo` (versione `1.4`), che non
richiede né nonce né firma:

```
supportedRoutes: [ ..., deleteallfcmtokens, deletefcmtoken, deletemessage, ... ]
```

Se `supportedRoutes` è presente e non le elenca, il server è più vecchio: ripiega su
`unregisterfcmtoken`. Se il campo è vuoto o assente, il server non è in grado di dichiarare
le proprie route: prova semplicemente la chiamata.

## 9. Cosa resta aperto dalla nostra parte

Due identità sullo stesso dispositivo non possono ancora avere lo stesso token FCM **nello
stesso momento**: la chiave primaria ne ammette una sola. Cancellare prima di registrare
funziona perché le due non si sovrappongono mai. Supportare push multi-identità davvero
simultanee richiede una decisione di schema e di privacy dalla nostra parte (una chiave
composta renderebbe le due identità correlabili) ed è tracciata separatamente. Non blocca
nulla di quanto descritto qui.
