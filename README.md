# TAKAMAKA Dart SDK - Example Usage

This repository contains examples of how to use the `TkmWalletService` in Dart to interact with the
Takamaka blockchain. The following are the essential steps to create wallets, handle transactions,
and manage staking.

## Getting Started

To include the **Takamaka SDK** in your Dart or Flutter project, add the following to
your `pubspec.yaml` file:

```yaml
dependencies:
  takamaka_sdk_wrap:
    git:
      url: https://github.com/massimiliano-andreatta/takamaka-sdk-wrap
      ref: main
```

Then, retrieve the package using:

```bash
flutter pub get
```

## Features

- [x] Initialize the Wallet Service
- [x] Retrieve Blockchain Settings
- [x] Get Available Currency List
- [x] Retrieve Exchange Rates
- [x] Retrieve Existing Wallets
- [x] Create a New Wallet
- [x] Get Wallet Addresses
- [x] Get a Wallet by Name
- [x] Check if a Wallet Exists by Name
- [x] Get all Address for all Wallet
- [x] Retrieve Transaction List
- [x] Retrieve Address Balance
- [x] Retrieve Node List for Staking
- [x] Get all Accepted Bets
- [x] Retrieve QTESLA Address of a Node
- [x] Stake TKG on a Node
- [x] Undo Stake
- [x] Send TKG (Green Token)
- [x] Send TKR (Red Token)
- [x] Send Blob File
- [x] Send Blob Hash
- [x] Send Blob Text
- [x] Gestione QRCode per Pagamenti (Azione PAY)
- [x] Search Transactions
- [ ] Login User
- [ ] Get info User
- [ ] Get list address user sync
- [ ] Sync address

---

### Initialize the Wallet Service

You can initialize the Takamaka wallet service for either the test or production environment:

```dart
TkmWalletService(currentEnv: TkmWalletEnumEnvironments.test);
```

## Blockchain Settings and Currency Information

### Retrieve Blockchain Settings

To get the current blockchain settings:

```dart
var settingsBlockchain = await TkmWalletService.callApiGetSettingsBlockchain();
```

### Get Available Currency List

To get the list of supported currencies on the Takamaka blockchain:

```dart
var currencyList = await TkmWalletService.callApiGetCurrencyList();
```

### Retrieve Exchange Rates

To retrieve the current exchange rates of the available currencies:

```dart
var currenciesExchangeRate = await TkmWalletService.callApiGetCurrenciesExchangeRate();
```

## Wallet Management

### Get a Wallet by Name

Get wallet by its name:

```dart
var wallet = await TkmWalletService.getWalletByName(walletName: 'myWallet');
```

### Check if a Wallet Exists by Name

To check if a wallet exists by its name:

```dart
bool exists = await TkmWalletService.existWalletByName(walletName:
```

### Retrieve Existing Wallets

To retrieve saved wallets from shared preferences:

```dart
var wallets = await TkmWalletService.getWallets();
```

### Create a New Wallet

If there are no existing wallets, you can create a new one:

```dart
var wallet = await TkmWalletService.createWallet(walletName: 'myWallet', password: 'myPassword');
List<String> wordsWalletRecovery = wallet.generatedWordsInitWallet; // 25 recovery words
await TkmWalletService.saveWallet(wallet: wallet);
```

### Get Wallet Addresses

The first address in the wallet is the main address:

```dart
var addressMain = wallet.addresses.first;
```

You can add new addresses to the wallet:

```dart
var addressOther = wallet.addAddress(1);
await TkmWalletService.saveWallet(wallet: wallet); // Don't forget to save changes
```

### Retrieve Address Balance

To check the balance of a specific address:

```dart
var walletBalance = await TkmWalletService.callApiGetBalance(address: addressMain.address);
```

## Transaction Management

### Retrieve Transaction List

To retrieve a list of transactions for a specific address, you can use:

```dart
List<TkmWalletTransaction> transactionList = await TkmWalletService.callApiGetTransactionList(address: addressMain.address, typeTransaction: TkmWalletEnumTypeTransaction.pay);
```

### PAY Transactions

I added the "calculateTransactionFee" method to calculate the transaction cost. After the user presses the send button, the "calculateTransactionFee" method should be called, and the value should be displayed in an alert.

#### Send TKG (Green Token)

To create and send a PAY transaction with TKG:

```dart
var valueGreen = TKmTK.unitStringTK("1.20");
var transactionPay_TKG = await addressMain.createTransactionPayTkg (to: addressMain.address, bigIntValue: valueGreen,message: "test");

var transaction = await addressMain.verifyTransactionIntegrity(transactionPay_TKG);
var transactionFee = await addressMain.calculateTransactionFee(transactionPay_TKG);
var transactionSend = await addressMain.prepareTransactionForSend(transactionPay_TKG);
var resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
```

#### Send TKR (Red Token)

Similarly, to create and send a PAY transaction with TKR:

```dart
var valueRed = TKmTK.unitStringTK("1.20");
var transactionPay_TKR = await addressMain.createTransactionPayTkr (to: addressMain.address, bigIntValue: valueRed, message: "test");

var transaction = await addressMain.verifyTransactionIntegrity(transactionPay_TKR);
var transactionFee = await addressMain.calculateTransactionFee(transactionPay_TKR);
var transactionSend = await addressMain.prepareTransactionForSend(transactionPay_TKR);
var resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
```

### BLOB Transactions

### BLOB HASH Transaction

Similarly, to create and send a BLOB HASH transaction with HASH File:

```dart
File fileTransaction = File("Path to the file location");
var transactionBlobHash = await addressMain.createTransactionBlobHash(file: fileTransaction);
// Check if it's a valid transaction before proceeding with the transaction cost calculation
transaction = await addressMain.verifyTransactionIntegrity(transactionBlobHash);
var transactionFee = await addressMain.calculateTransactionFee(transactionBlobHash);
// Prepare the transaction for sending
transactionSend = await addressMain.prepareTransactionForSend(transactionBlobHash);
resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend); // Call the API to send the transaction to the blockchain

```

### BLOB FILE Transaction

Similarly, to create and send a BLOB FILE transaction with BLOB File:

```dart
File fileTransaction = File("Path to the file location");
var transactionBlobFile = await addressMain.createTransactionBlobFile(file: fileTransaction, tags: ["tag1", "tag2", "tag3"]);
// Check if it's a valid transaction before proceeding with the transaction cost calculation
transaction = await addressMain.verifyTransactionIntegrity(transactionBlobFile);
var transactionFee = await addressMain.calculateTransactionFee(transactionBlobFile);
// Prepare the transaction for sending
transactionSend = await addressMain.prepareTransactionForSend(transactionBlobFile);
resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend); // Call the API to send the transaction to the blockchain

```

### BLOB TEXT Transaction

Similarly, to create and send a BLOB TEXT transaction with HASH File:

```dart
var transactionBlobText = await addressMain.createTransactionBlobText(message: "test text");
// Check if it's a valid transaction before proceeding with the transaction cost calculation
transaction = await addressMain.verifyTransactionIntegrity(transactionBlobText);
var transactionFee = await addressMain.calculateTransactionFee(transactionBlobText);
// Prepare the transaction for sending
transactionSend = await addressMain.prepareTransactionForSend(transactionBlobText);
resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend); // Call the API to send the transaction to the blockchain

```

## Gestione QRCode per Pagamenti (PAY Action)

Questa funzionalità permette di generare QRCode per avviare pagamenti e di interpretare i dati da tali QRCode all'interno di applicazioni Flutter. Il sistema è progettato per essere compatibile con una specifica struttura JSON generata da un backend Java.

### Componenti Chiave

- **Modelli Dati:**
  - [`PayQrData`](lib/models/actions/pay_qr_data.dart:3): Rappresenta i dati contenuti in un QRCode "PAY".
  - [`PayActionDetails`](lib/models/actions/pay_qr_data.dart:62): Dettagli specifici dell'azione di pagamento (contenuti in `PayQrData`).
  - [`RecipientAddress`](lib/models/actions/pay_qr_data.dart:103): Indirizzo del destinatario (contenuto in `PayActionDetails`).
    Questi modelli sono definiti nel file [`lib/models/actions/pay_qr_data.dart`](lib/models/actions/pay_qr_data.dart).
- **Servizio:**
  - [`QrCodeService`](lib/servicies/qr_code_service.dart:6): Fornisce metodi per generare widget QRCode e per interpretare dati JSON da QRCode. Questo servizio è definito in [`lib/servicies/qr_code_service.dart`](lib/servicies/qr_code_service.dart).

### Come Generare un QRCode "PAY"

1.  **Creare l'istanza `PayQrData`:**
    Utilizzare il factory constructor [`PayQrData.create(...)`](lib/models/actions/pay_qr_data.dart:14) per costruire l'oggetto con i dettagli del pagamento.

    ```dart
    // Esempio di creazione dati per QR PAY
    final payData = PayQrData.create(
      recipientAddressString: "BASE64_URL_ENCODED_ADDRESS", // Indirizzo del destinatario codificato in Base64URL
      recipientType: "f", // Tipo destinatario: "f" per standard (EOA), "c" per contract
      green: BigInt.from(1000000000), // Importo in TKG (nanoTKG, opzionale, es. 1 TKG)
      message: "Pagamento test", // Messaggio (opzionale)
    );
    ```

2.  **Generare il Widget QRCode:**
    Usare il metodo [`QrCodeService.generatePayQrWidget(payData)`](lib/servicies/qr_code_service.dart:21) per ottenere un widget Flutter che visualizza il QRCode. Questo widget può essere inserito direttamente nell'interfaccia utente della vostra applicazione.

    ```dart
    // Esempio di generazione del widget
    final qrCodeWidget = QrCodeService.generatePayQrWidget(payData);

    // Successivamente, puoi usare qrCodeWidget in un Widget Flutter,
    // ad esempio dentro un Container, AlertDialog o SizedBox:
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     content: SizedBox(
    //       width: 200,
    //       height: 200,
    //       child: qrCodeWidget,
    //     ),
    //   ),
    // );
    ```

### Come Leggere/Interpretare un QRCode "PAY"

1.  **Ottenere la Stringa JSON dal QRCode:**
    Il primo passo consiste nello scansionare il QRCode. Per fare ciò, è possibile utilizzare un package Flutter dedicato alla scansione di codici a barre/QR, come ad esempio [`mobile_scanner`](https://pub.dev/packages/mobile_scanner). La scansione restituirà una stringa che rappresenta i dati JSON contenuti nel QRCode.

2.  **Convertire la Stringa JSON in `PayQrData`:**
    Una volta ottenuta la stringa JSON, utilizzare il metodo [`QrCodeService.parsePayQrJson(jsonStringFromQr)`](lib/servicies/qr_code_service.dart:56) per effettuare il parsing della stringa e convertirla in un oggetto `PayQrData?`. Il risultato sarà `null` se la stringa JSON non è valida, non è conforme alla struttura attesa, o se il tipo di azione non è "rp" (request_pay).

    ```dart
    // Esempio di parsing del JSON (ipotizzando una funzione scanQrCode())
    // String? jsonStringFromQr = await scanQrCodeFunction(); // Sostituire con la logica di scansione effettiva

    // Esempio con una stringa JSON fittizia
    String jsonStringFromQr = '''
    {
      "v": "1.0",
      "a": {
        "to": {"t": "f", "ma": "BASE64_URL_ENCODED_ADDRESS"},
        "g": "1000000000",
        "tm": "Test"
      },
      "t": "rp"
    }
    ''';

    final PayQrData? parsedData = QrCodeService.parsePayQrJson(jsonStringFromQr);

    if (parsedData != null) {
      // Utilizza i dati estratti da parsedData
      print("Versione: ${parsedData.version}");
      print("Tipo Azione: ${parsedData.type}");
      print("Destinatario (tipo): ${parsedData.action.to.type}");
      print("Destinatario (indirizzo): ${parsedData.action.to.recipientAddress}");
      if (parsedData.action.greenAmount != null) {
        print("Importo TKG (nano): ${parsedData.action.greenAmount}");
      }
      if (parsedData.action.message != null) {
        print("Messaggio: ${parsedData.action.message}");
      }
    } else {
      print("Errore: JSON del QRCode non valido o tipo azione non supportato.");
    }
    ```

### Struttura JSON del QRCode

Di seguito è mostrata la struttura JSON che viene generata e interpretata per i QRCode "PAY". Questo formato è cruciale per assicurare l'interoperabilità.

```json
{
  "v": "1.0", // Versione dello schema del QR
  "a": {
    // Action Details (Dettagli dell'azione)
    "to": {
      // Recipient (Destinatario)
      "t": "address_type", // Tipo di indirizzo: "f" (normale/EOA), "c" (contratto)
      "ma": "recipient_address_base64url" // Indirizzo del destinatario (Base64URL encoded)
    },
    "g": "green_amount_nanoTKG_as_string", // Importo TKG in nanoTKG (stringa, opzionale)
    "r": "red_amount_nanoTKR_as_string", // Importo TKR in nanoTKR (stringa, opzionale)
    "tm": "text_message" // Messaggio testuale (opzionale)
  },
  "t": "rp" // Action Type (Tipo di azione, deve essere "rp" per request_pay)
}
```

- `v`: Versione dello schema JSON. Attualmente `"1.0"`.
- `a`: Contiene i dettagli dell'azione di pagamento.
  - `to`: Oggetto che descrive il destinatario.
    - `t`: Tipo di indirizzo del destinatario. Può essere `"f"` per un indirizzo standard (Externally Owned Account) o `"c"` per un indirizzo di contratto.
    - `ma`: L'indirizzo effettivo del destinatario, codificato in formato Base64URL.
  - `g` (Opzionale): Importo in TKG (token verde), espresso come stringa di un numero intero (nanoTKG).
  - `r` (Opzionale): Importo in TKR (token rosso), espresso come stringa di un numero intero (nanoTKR).
  - `tm` (Opzionale): Un messaggio testuale associato al pagamento.
- `t`: Tipo di azione. Per i QRCode di pagamento, questo valore è fisso a `"rp"` (request_pay).

### Dipendenze

- **`qr_flutter`**: Questa libreria è utilizzata internamente dal [`QrCodeService`](lib/servicies/qr_code_service.dart:6) per la generazione effettiva dei widget QRCode. È una dipendenza del package `takamaka_sdk_wrap` ed è già gestita nel suo file [`pubspec.yaml`](pubspec.yaml). Non è necessario aggiungerla separatamente nel progetto che utilizza l'SDK.
- **Scanner QRCode (Raccomandazione per il Progetto Utilizzatore)**: Per la funzionalità di lettura/scansione dei QRCode nell'applicazione finale, è necessario integrare un package apposito. Si raccomanda l'uso di [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) o un'alternativa simile. Questa dipendenza dovrà essere aggiunta al file `pubspec.yaml` del progetto Flutter che consuma `takamaka_sdk_wrap`.

  Esempio di aggiunta al `pubspec.yaml` del progetto client:

  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    takamaka_sdk_wrap: # Già presente se si segue l'installazione dell'SDK
      git:
        url: https://github.com/massimiliano-andreatta/takamaka-sdk-wrap
        ref: main
    mobile_scanner: ^LATEST_VERSION # Sostituire LATEST_VERSION con la versione desiderata
    # ... altre dipendenze
  ```

## Staking

### Retrieve Node List for Staking

To retrieve the list of nodes available for staking:

```dart
var listNode = await TkmWalletService.callApiGetNodeList();
```

### Retrieve QTESLA Address of a Node

To retrieve the QTESLA address for staking on a specific node:

```dart
var shortAddressNode = listNode[0].shortAddress ?? "";
var resultRetriveQtesla = await TkmWalletService.callApiRetriveNodeQteslaAddress(shortAddressNode: shortAddressNode);
```

### Get all Accepted Bets

To retrieve the Accepted Bets

```dart
var resultRetriveAcceptedBets = await TkmWalletService.getAcceptedBets(address: addressMain.address);
```

### Stake TKG on a Node

If a QTESLA address is available, you can create a stake transaction:

```dart
if (resultRetriveQtesla != null || !resultRetriveQtesla!.isEmpty) {
var valueStake = TKmTK.unitStringTK("200");
var transactionStake = await addressMain.createTransactionStakeAdd(
qteslaAddress: resultRetriveQtesla, bigIntValue: valueStake, message: "Stake");

var transaction = await addressMain.verifyTransactionIntegrity(transactionStake);
var transactionFee = await addressMain.calculateTransactionFee(transactionStake);
var transactionSend = await addressMain.prepareTransactionForSend(transactionStake);
var resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
}
```

### Undo Stake

To undo all stakes made previously:

```dart
var transactionStakeUndo = await addressMain.createTransactionStakeUndo();

var transaction = await addressMain.verifyTransactionIntegrity(transactionStakeUndo);
var transactionFee = await addressMain.calculateTransactionFee(transactionStakeUndo);
var transactionSend = await addressMain.prepareTransactionForSend(transactionStakeUndo);
var resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend:transactionSend);
```

## Notifications

Regarding the notifications, these are not push notifications but direct notifications to the user. For now, there are no TAKAMAKA APIs that return this information, but the wrap SDK has implemented APIs with mock data.

```dart

var callGetNotifications = await TkmWalletService.authGetNotifications(token: loginResponse!.token);
callGetNotifications.fold(
          //Error
          (left) {
            print(left.message);
          },
          //Success
          (right) {
            print(right);
          },
        );

```

## API Auth

## Login

```dart
TkmLoginResponse? loginResponse = null;

var loginRequest = TkmLoginRequest(username: "xxxxxx.xxxxx@xxxxx.xxxxx", password: "password", deviceId: "deviceId");
var callLogin = await TkmWalletService.authLogin(loginRequest: loginRequest);
callLogin.fold(
        (left) {
          print(left.message);
        },
        (right) {
          loginResponse = right;
        },
      );

```

## Refresh Token

```dart
var callRefreshToken = await TkmWalletService.authRefreshToken(refreshToken: loginResponse!.refreshToken!, username: loginRequest.username, deviceId: loginRequest.deviceId);
callRefreshToken.fold(
          //Error
          (left) {
            print(left.message);
          },
          //Success
          (right) {
            loginResponse = right;
          },
        );
```

## Info User

```dart
var callGetInfoUser = await TkmWalletService.authGetInfoUser(token: loginResponse!.token);
callGetInfoUser.fold(
          //Error
          (left) {
            print(left.message);
          },
          //Success
          (right) {
            print(right);
          },
        );
```

## Get List Address Register For User

```dart
var callGetListAddress = await TkmWalletService.authGetListAddress(token: loginResponse!.token);
callGetListAddress.fold(
          //Error
          (left) {
            print(left.message);
          },
          //Success
          (right) {
            print(right);
          },
        );
```

## Sync Address

```dart
var callSyncAddress = await TkmWalletService.authSyncAddress(token: loginResponse!.token, walletAddress: "walletAddress");
callSyncAddress.fold(
          //Error
          (left) {
            print(left.message);
          },
          //Success
          (right) {
            print(right);
          },
        );
```
