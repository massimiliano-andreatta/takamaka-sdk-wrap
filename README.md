
# TkmWalletService

`TkmWalletService` is a Dart package that simplifies the management of wallets and transactions on the TAKAMAKA blockchain. The service allows you to create, save, retrieve wallets, and perform various types of transactions, including sending payments (TKG/TKR) and handling staking operations.

## Features

- **Wallet Management:** Create, save, and load wallets using shared preferences.
- **Transaction Types:** Send payments, stake tokens, and undo stake transactions.
- **API Integration:** Interact with the TAKAMAKA blockchain API for transaction handling.

## Getting Started

### Installation

To use this package, add it to your `pubspec.yaml` file:

```yaml
dependencies:
  tkm_wallet_service: latest_version
```

Then, run `flutter pub get` to install the package.

### Initialization

To initialize the service, you need to specify the environment (either `test` or `production`):

```dart
TkmWalletService(currentEnv: TkmWalletEnumEnvironments.test);
```

### Wallet Management

#### Retrieve Saved Wallets

You can retrieve the wallets stored in shared preferences as follows:

```dart
var wallets = await TkmWalletService.getWallets();

TkmWalletWrap wallet;
if (wallets.isNotEmpty) {
  wallet = wallets.first;
} else {
  // Create a new wallet if none exist
  wallet = await TkmWalletService.createWallet(walletName: 'myWallet', password: 'myPassword');

  // Get the 25 recovery words for the wallet
  List<String> wordsWalletRecovery = wallet.generatedWordsInitWallet;

  // Save the wallet
  await TkmWalletService.saveWallet(wallet: wallet);
}
```

#### Manage Wallet Addresses

- **Get the main wallet address:**

```dart
var addressMain = wallet.addresses.first;
```

- **Add a new wallet address:**

```dart
var addressOther = wallet.addAddress(1);
```

- **Save changes to the wallet:**

```dart
await TkmWalletService.saveWallet(wallet: wallet);
```

### Transactions

#### PAY Transactions

You can send TAKAMAKA tokens (`TKG` or `TKR`) using the following methods:

- **Sending TKG:**

```dart
var valueGreen = TKmTK.unitStringTK("1.20");
var transactionPay_TKG = await addressMain.createTransactionPayTkg(to: addressMain.address, bigIntValue: valueGreen, message: "test");

// Verify transaction integrity
var transaction = await addressMain.verifyTransactionIntegrity(transactionPay_TKG);

// Prepare and send the transaction
var transactionSend = await addressMain.prepareTransactionForSend(transactionPay_TKG);
var resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
```

- **Sending TKR:**

```dart
var valueRed = TKmTK.unitStringTK("1.20");
var transactionPay_TKR = await addressMain.createTransactionPayTkr(to: addressMain.address, bigIntValue: valueRed, message: "test");

// Verify transaction integrity
transaction = await addressMain.verifyTransactionIntegrity(transactionPay_TKR);

// Prepare and send the transaction
transactionSend = await addressMain.prepareTransactionForSend(transactionPay_TKR);
resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
```

#### STAKE Transactions

- **Stake Tokens:**

```dart
var listNode = await TkmWalletService.callApiGetNodeList();
var shortAddressNode = listNode[0].shortAddress ?? "";
var resultRetriveQtesla = await TkmWalletService.callApiRetriveNodeQteslaAddress(shortAddressNode: shortAddressNode);

if (resultRetriveQtesla != null) {
  var valueStake = TKmTK.unitStringTK("200");
  var transactionStake = await addressMain.createTransactionStakeAdd(qteslaAddress: resultRetriveQtesla, bigIntValue: valueStake, message: "Stake");

  // Verify transaction integrity
  transaction = await addressMain.verifyTransactionIntegrity(transactionStake);

  // Prepare and send the transaction
  transactionSend = await addressMain.prepareTransactionForSend(transactionStake);
  resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
}
```

- **Undo Stake:**

```dart
var transactionStakeUndo = await addressMain.createTransactionStakeUndo();
transaction = await addressMain.verifyTransactionIntegrity(transactionStakeUndo);
transactionSend = await addressMain.prepareTransactionForSend(transactionStakeUndo);
resultPaySend = await TkmWalletService.callApiSendingTransaction(transactionSend: transactionSend);
```

### License

This package is available under the MIT License.
