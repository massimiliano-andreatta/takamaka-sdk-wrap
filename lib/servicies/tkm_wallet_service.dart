import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_wallet_enum_type_transaction.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_wallet_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/api/tkm_wallet_staking_node.dart';
import 'package:takamaka_sdk_wrap/models/api/tkm_wallet_transaction.dart';
import 'package:takamaka_sdk_wrap/models/api/tkm_wallet_transaction_result.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_exceptions.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_wrap.dart';
import 'package:takamaka_sdk_wrap/servicies/tkm_wallet_client_api.dart';

class TkmWalletService {
  static const String _walletKey = 'wallets';

  // Initialize the API client for wallet interactions, targeting the test environment
  static late TkmWalletClientApi _clientApi;

  TkmWalletService({required TkmWalletEnumEnvironments currentEnv}) {
    _clientApi = TkmWalletClientApi(currentEnv: TkmWalletEnumEnvironments.test, dicClient: Dio());
  }
  // Creates a new wallet and saves it to SharedPreferences
  static Future<TkmWalletWrap> createWallet(String walletName, String password) async {
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

    // Save the new wallet to shared preferences for persistence
    await saveWallet(wallet);

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
  static Future<void> saveWallet(TkmWalletWrap wallet) async {
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
  static Future<void> deleteWallet(String walletName) async {
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
  static Future<void> addAddressToWallet(TkmWalletWrap walletName, int index) async {
    List<TkmWalletWrap> wallets = await getWallets();

    // Find the wallet by its name
    TkmWalletWrap? wallet = wallets.firstWhere(
          (w) => w.walletName == walletName.walletName,
      orElse: () => throw WalletNotFoundException("Wallet not found"),
    );

    // Add a new address to the wallet at the given index
    await wallet.addAddress(index);

    // Save the updated wallet back to SharedPreferences
    await saveWallet(wallet);
  }

  // Retrieves a specific wallet by its name
  static Future<TkmWalletWrap> getWalletByName(String walletName) async {
    List<TkmWalletWrap> wallets = await getWallets();

    // Find and return the wallet by its name, or throw an exception if not found
    return wallets.firstWhere(
          (w) => w.walletName == walletName,
      orElse: () => throw WalletNotFoundException("Wallet $walletName not found"),
    );
  }

  // Calls the API to retrieve a list of staking nodes
  static Future<List<TkmWalletStakingNode>> callApiGetNodeList() async {
    var result = await _clientApi.getStakingNodeList();
    return result;
  }

  // Calls the API to retrieve a list of transactions based on the address and transaction type
  static Future<List<TkmWalletTransaction>> callApiGetTransactionList({required String address, required TkmWalletEnumTypeTransaction typeTransaction, int pageIndex = 0, int numberItemsForPage = 200}) async {
    var result = await _clientApi.getTransactionList(typeTransaction: typeTransaction, pageIndex: pageIndex, numberItemsForPage: numberItemsForPage, address: address);
    return result;
  }

  // Calls the API to retrieve a node's Qtesla address based on its short address
  static Future<String?> callApiRetriveNodeQteslaAddress({required String shortAddressNode}) async {
    var result = await _clientApi.retriveNodeQteslaAddress(shortAddressNode: shortAddressNode);
    return result;
  }

  // Calls the API to retrieve the balance of a specific address
  static Future<String?> callApiGetBalance({required String address}) async {
    var result = await _clientApi.getBalance(address: address);
    return result;
  }

  // Calls the API to send a transaction
  static Future<TkmTransactionTransactionResult> callApiSendingTransaction({required TransactionInput transactionSend}) async {
    var result = await _clientApi.sendingTransaction(transactionSend: transactionSend);
    return result;
  }
}
