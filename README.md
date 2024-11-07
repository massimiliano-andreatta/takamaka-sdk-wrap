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
- [ ] Generate QRCODE recive token (TKG/TKR)
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
var resultRetriveAcceptedBets = await getAcceptedBets(address: addressMain.address);
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

This `README.md` provides detailed instructions on integrating the Takamaka Dart SDK into your
project, managing wallets, transactions, and staking. Be sure to check the SDK documentation for
additional features and best practices.