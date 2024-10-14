library takamaka_sdk_wrap;

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../enums/tkm_wallet_enum_type_transaction.dart';
import '../enums/tkm_wallet_enums_api.dart';
import '../models/api/tkm_wallet_balance.dart';
import '../models/api/tkm_wallet_blockchain_settings.dart';
import '../models/api/tkm_wallet_currencies_change.dart';
import '../models/api/tkm_wallet_currency.dart';
import '../models/api/tkm_wallet_staking_node.dart';
import '../models/api/tkm_wallet_transaction_response.dart';
import '../models/api/tkm_wallet_transaction_result.dart';
import '../models/tkm_wallet_exceptions.dart';
import '../models/tkm_wallet_wrap.dart';
import 'tkm_wallet_client_api.dart';

class TkmWalletService {
  static const String _walletKey = 'wallets';

  // Initialize the API client for wallet interactions, targeting the test environment
  static late TkmWalletClientApi _clientApi;

  TkmWalletService({required TkmWalletEnumEnvironments currentEnv}) {
    _clientApi = TkmWalletClientApi(currentEnv: TkmWalletEnumEnvironments.test, dicClient: Dio());
  }

  /// Creates a new wallet and saves it to SharedPreferences.
  ///
  /// This method checks if a wallet with the same name already exists. If it does,
  /// it throws a WalletAlreadyExistsException. If not, it creates a new wallet
  /// with the provided name and password, initializes it, and returns the wallet.
  ///
  /// Parameters:
  /// - [walletName]: The name of the wallet to be created.
  /// - [password]: The password for the wallet.
  ///
  /// Returns:
  /// - A [TkmWalletWrap] object representing the newly created wallet.
  static Future<TkmWalletWrap> createWallet({required String walletName, required String password }) async {
    // Retrieve all existing wallets from storage
    List<TkmWalletWrap> wallets = await getWallets();

    // Check if a wallet with the same name already exists
    bool walletExists = wallets.any((w) => w.walletName == walletName);
    if (walletExists) {
      // If a wallet with the same name exists, throw an exception
      throw WalletAlreadyExistsException("A wallet with the name '$walletName' already exists.");
    }

    // Create a new wallet with the provided name and password
    TkmWalletWrap wallet = TkmWalletWrap(walletName, password);

    // Initialize the wallet (generating seed words if necessary)
    await wallet.initializeWallet();

    // Return the newly created wallet object
    return wallet;
  }

  /// Retrieves all wallets stored in SharedPreferences.
  ///
  /// This method fetches the list of wallet JSON strings from SharedPreferences,
  /// converts them into TkmWalletWrap objects, and returns them as a list.
  ///
  /// Returns:
  /// - A [Future<List<TkmWalletWrap>>] containing all wallets.
  static Future<List<TkmWalletWrap>> getWallets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the wallet list from shared preferences (if exists)
    List<String>? walletJsonList = prefs.getStringList(_walletKey);

    // If no wallets exist, return an empty list
    if (walletJsonList == null) {
      return [];
    }

    // Convert the JSON strings into TkmWalletWrap objects asynchronously
    List<TkmWalletWrap> wallets = await Future.wait(walletJsonList.map(
          (walletJson) async => TkmWalletWrap.fromJson(jsonDecode(walletJson)),
    ));

    return wallets;
  }

  /// Saves or updates a wallet in SharedPreferences.
  ///
  /// This method retrieves the current list of wallets, checks if the wallet
  /// already exists, and either updates it or adds it to the list. Finally,
  /// it saves the updated wallet list back to SharedPreferences.
  ///
  /// Parameters:
  /// - [wallet]: The wallet to be saved or updated.
  static Future<void> saveWallet({required TkmWalletWrap wallet}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current list of wallets from storage
    List<String>? walletJsonList = prefs.getStringList(_walletKey);
    walletJsonList ??= [];

    // Convert JSON strings into wallet objects asynchronously
    List<TkmWalletWrap> wallets = await Future.wait(walletJsonList.map(
          (walletJson) async => TkmWalletWrap.fromJson(jsonDecode(walletJson)),
    ));

    // Find if a wallet with the same name already exists
    int existingWalletIndex =
    wallets.indexWhere((w) => w.walletName == wallet.walletName);

    if (existingWalletIndex != -1) {
      // If it exists, update the existing wallet
      wallets[existingWalletIndex] = wallet;
    } else {
      // If not, add the new wallet to the list
      wallets.add(wallet);
    }

    // Convert the updated wallet list back to JSON and save it
    List<String> updatedWalletJsonList =
    wallets.map((w) => jsonEncode(w.toJson())).toList();

    await prefs.setStringList(_walletKey, updatedWalletJsonList);
  }

  /// Deletes a wallet by its name from SharedPreferences.
  ///
  /// This method retrieves the current list of wallets, removes the specified
  /// wallet, and saves the updated list back to SharedPreferences.
  ///
  /// Parameters:
  /// - [walletName]: The name of the wallet to be deleted.
  static Future<void> deleteWallet({required String walletName}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current list of wallets from storage
    List<String>? walletJsonList = prefs.getStringList(_walletKey);
    walletJsonList ??= [];

    // Convert JSON strings into wallet objects asynchronously
    List<TkmWalletWrap> wallets = await Future.wait(walletJsonList.map(
          (walletJson) async => TkmWalletWrap.fromJson(jsonDecode(walletJson)),
    ));

    // Remove the wallet with the matching name
    wallets.removeWhere((wallet) => wallet.walletName == walletName);

    // Save the updated wallet list back to SharedPreferences
    List<String> updatedWalletJsonList =
    wallets.map((w) => jsonEncode(w.toJson())).toList();

    await prefs.setStringList(_walletKey, updatedWalletJsonList);
  }

  /// Adds a new address (wallet) to an existing wallet by its index.
  ///
  /// This method retrieves all wallets, finds the specified wallet,
  /// and adds a new address to it at the given index.
  ///
  /// Parameters:
  /// - [wallet]: The wallet to which the address will be added.
  /// - [index]: The index at which to add the new address.
  static Future<void> addAddressToWallet({required TkmWalletWrap walletName, required int index}) async {
    // Retrieve all wallets from SharedPreferences
    List<TkmWalletWrap> wallets = await getWallets();

    // Find the wallet by its name
    TkmWalletWrap? wallet = wallets.firstWhere(
          (w) => w.walletName == walletName.walletName,
      orElse: () => throw WalletNotFoundException("Wallet not found"),
    );

    // Add a new address to the wallet at the given index
    await wallet.addAddress(index);
  }

  /// Retrieves a specific wallet by its name.
  ///
  /// This method fetches all wallets and returns the one matching the specified
  /// name. If the wallet is not found, it throws a WalletNotFoundException.
  ///
  /// Parameters:
  /// - [walletName]: The name of the wallet to retrieve.
  ///
  /// Returns:
  /// - A [TkmWalletWrap] object representing the requested wallet.
  static Future<TkmWalletWrap> getWalletByName({required String walletName}) async {
    // Retrieve all wallets from SharedPreferences
    List<TkmWalletWrap> wallets = await getWallets();

    // Find and return the wallet by its name, or throw an exception if not found
    return wallets.firstWhere(
          (w) => w.walletName == walletName,
      orElse: () => throw WalletNotFoundException("Wallet $walletName not found"),
    );
  }

  /// Calls the API to retrieve a list of staking nodes.
  ///
  /// This method requests the list of staking nodes from the API
  /// and returns the result.
  ///
  /// Returns:
  /// - A [Future<List<TkmWalletStakingNode>>] containing the list of staking nodes.
  static Future<List<TkmWalletStakingNode>> callApiGetNodeList() async {
    // Request the list of staking nodes from the API
    var result = await _clientApi.getStakingNodeList();
    return result;
  }

  /// Calls the API to retrieve a list of transactions based on the address and transaction type.
  ///
  /// This method requests the list of transactions from the API based on the given parameters
  /// and returns the result.
  ///
  /// Parameters:
  /// - [address]: The wallet address for which to retrieve transactions.
  /// - [typeTransaction]: The type of transactions to retrieve.
  /// - [pageIndex]: The index of the page of results to retrieve (default is 0).
  /// - [numberItemsForPage]: The number of items to retrieve per page (default is 10).
  ///
  /// Returns:
  /// - A [Future<List<TkmWalletTransactionResponse>>] containing the list of transactions.
  static Future<List<TkmWalletTransaction>> callApiGetTransactionList({
    required String address,
    required TkmWalletEnumTypeTransaction typeTransaction,
    int pageIndex = 0,
    int numberItemsForPage = 10,
  }) async {
    // Request the list of transactions from the API
    var result = await _clientApi.getTransactionList(
      address: address,
      typeTransaction: typeTransaction,
      pageIndex: pageIndex,
      numberItemsForPage: numberItemsForPage,
    );

    return result;
  }

  /// Calls the API to retrieve the balance for a specified address.
  ///
  /// This method requests the balance for the given address from the API
  /// and returns the result.
  ///
  /// Parameters:
  /// - [address]: The wallet address for which to retrieve the balance.
  ///
  /// Returns:
  /// - A [Future<TkmWalletBalance>] containing the balance for the specified address.
  static Future<TkmWalletBalance?> callApiGetBalance({required String address}) async {
    // Request the balance from the API
    var result = await _clientApi.getBalance(address: address);
    return result;
  }

  /// Calls the API to retrieve the settings for blockchain interaction.
  ///
  /// This method requests the blockchain settings from the API
  /// and returns the result.
  ///
  /// Returns:
  /// - A [Future<TkmWalletBlockchainSettings>] containing the blockchain settings.
  static Future<TkmWalletBlockchainSettings?> callApiGetBlockchainSettings() async {
    // Request the blockchain settings from the API
    var result = await _clientApi.getBlockchainSettings();
    return result;
  }

  /// Calls the API to change the currency for transactions.
  ///
  /// This method requests a change of currency from the API
  /// and returns the result.
  ///
  /// Parameters:
  /// - [currency]: The currency to change to.
  ///
  /// Returns:
  /// - A [Future<TkmWalletCurrenciesChange>] containing the result of the currency change.
  static Future<TkmWalletCurrenciesChange?> callApiChangeCurrency() async {
    // Request a currency change from the API
    var result = await _clientApi.getChangeCurrency();
    return result;
  }

  /// Calls the API to send a transaction
  ///
  /// This static method interacts with the external API to send a transaction
  /// represented by the given TransactionInput. It is designed to be used
  /// asynchronously and returns a Future that resolves to the result of the
  /// transaction send operation.
  ///
  /// Parameters:
  /// - [transactionSend]: An instance of TransactionInput containing the details
  ///   of the transaction to be sent.
  ///
  /// Returns:
  /// A Future that resolves to an instance of TkmTransactionTransactionResult,
  /// which contains the result of the transaction send operation.
  static Future<TkmTransactionTransactionResult> callApiSendingTransaction({required TransactionInput transactionSend}) async {
    // Send the transaction via the API and retrieve the result
    // This uses the _clientApi instance to call the sendingTransaction method,
    // passing the transactionSend parameter. This method handles the actual API call.
    var result = await _clientApi.sendingTransaction(transactionSend: transactionSend);

    // Return the result of the API call
    // The result will include information such as transaction status,
    // transaction ID, and any error messages that may have occurred during the send operation.
    return result;
  }

}
