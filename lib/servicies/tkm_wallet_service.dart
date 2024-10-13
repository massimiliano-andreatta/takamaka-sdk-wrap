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

  // Creates a new wallet and saves it to SharedPreferences
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

  // Retrieves all wallets stored in SharedPreferences
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

  // Saves or updates a wallet in SharedPreferences
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

  // Deletes a wallet by its name from SharedPreferences
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

  // Adds a new address (wallet) to an existing wallet by its index
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

  // Retrieves a specific wallet by its name
  static Future<TkmWalletWrap> getWalletByName({required String walletName}) async {
    // Retrieve all wallets from SharedPreferences
    List<TkmWalletWrap> wallets = await getWallets();

    // Find and return the wallet by its name, or throw an exception if not found
    return wallets.firstWhere(
          (w) => w.walletName == walletName,
      orElse: () => throw WalletNotFoundException("Wallet $walletName not found"),
    );
  }

  // Calls the API to retrieve a list of staking nodes
  static Future<List<TkmWalletStakingNode>> callApiGetNodeList() async {
    // Request the list of staking nodes from the API
    var result = await _clientApi.getStakingNodeList();
    return result;
  }

  // Calls the API to retrieve a list of transactions based on the address and transaction type
  static Future<List<TkmWalletTransaction>> callApiGetTransactionList({
    required String address,
    required TkmWalletEnumTypeTransaction typeTransaction,
    int pageIndex = 0,
    int numberItemsForPage = 200}) async {
    // Request the list of transactions from the API based on parameters
    var result = await _clientApi.getTransactionList(
        typeTransaction: typeTransaction,
        pageIndex: pageIndex,
        numberItemsForPage: numberItemsForPage,
        address: address);
    return result;
  }

  // Calls the API to retrieve a node's Qtesla address based on its short address
  static Future<String?> callApiRetriveNodeQteslaAddress({required String shortAddressNode}) async {
    // Request the Qtesla address of the node from the API
    var result = await _clientApi.retriveNodeQteslaAddress(shortAddressNode: shortAddressNode);
    return result;
  }

  // Calls the API to retrieve the balance of a specific address
  static Future<TkmWalletBalance?> callApiGetBalance({required String address}) async {
    // Request the wallet balance from the API
    var result = await _clientApi.getBalance(address: address);
    return result;
  }

  // Calls the API to send a transaction
  static Future<TkmTransactionTransactionResult> callApiSendingTransaction({required TransactionInput transactionSend}) async {
    // Send the transaction via the API and retrieve the result
    var result = await _clientApi.sendingTransaction(transactionSend: transactionSend);
    return result;
  }

  // Calls the API to retrieve a list of supported currencies
  static Future<List<TkmWalletCurrency>> callApiGetCurrencyList() async {
    // Request the currency list from the API
    var result = await _clientApi.getCurrencyList();
    return result;
  }

  // Calls the API to retrieve blockchain settings
  static Future<TkmWalletBlockchainSettings?> callApiGetSettingsBlockchain() async {
    // Request blockchain settings from the API
    var result = await _clientApi.getSettingsBlockchain();
    return result;
  }

  // Calls the API to retrieve the exchange rates for currencies
  static Future<TkmWalletCurrenciesChange?> getCurrenciesExchangeRate() async {
    // Request the exchange rates from the API
    var result = await _clientApi.getCurrenciesExchangeRate();
    return result;
  }
}
