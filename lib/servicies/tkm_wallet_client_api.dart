library takamaka_sdk_wrap;

import 'package:dio/dio.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';

import '../enums/tkm_wallet_enum_type_transaction.dart';
import '../enums/tkm_wallet_enums_api.dart';
import '../models/api/tkm_wallet_balance.dart';
import '../models/api/tkm_wallet_blockchain_settings.dart';
import '../models/api/tkm_wallet_currencies_change.dart';
import '../models/api/tkm_wallet_currency.dart';
import '../models/api/tkm_wallet_list_node_response.dart';
import '../models/api/tkm_wallet_staking_node.dart';
import '../models/api/tkm_wallet_transaction_response.dart';
import '../models/api/tkm_wallet_transaction_result.dart';

// This class represents the result of a transaction, containing a success flag and a message.
class TransactionResult {
  final bool success;
  final String message;

  TransactionResult({required this.success, required this.message});
}

// TkmWalletClientApi is a class that wraps HTTP requests to the TkmWallet API.
class TkmWalletClientApi {
  final Dio _dicClient;
  final TkmWalletEnumEnvironments _currentEnv;

  // Constructor initializes the Dio HTTP client and the current environment.
  TkmWalletClientApi({required Dio dicClient, required TkmWalletEnumEnvironments currentEnv})
      : _dicClient = dicClient,
        _currentEnv = currentEnv;

  // Method to send a transaction. It takes a TransactionInput and returns a TransactionResult.
  Future<TkmTransactionTransactionResult> sendingTransaction({required TransactionInput transactionSend}) async {
    try {
      var tx = transactionSend.toJson(); // Convert the transaction input to JSON format.
      var data = FormData.fromMap(tx);   // Create a FormData object from the JSON.

      var enuEndpoint = TkmWalletEnumApiEndpoints.sendTransaction; // Get the endpoint.
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);        // Get the full API URL for the endpoint.
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);     // Get the HTTP method for the endpoint.

      // Send the HTTP request to the server.
      var response = await _dicClient.request(
        urlCall,
        options: Options(
          method: methodCall.toString(),  // Define the HTTP method (GET, POST, etc.).
        ),
        data: data,                       // Attach the form data to the request.
      );

      // If the response is successful (200 OK).
      if (response.statusCode == 200) {
        var responseData = response.data;  // Get the response data.

        // Check if the transaction is verified.
        if (responseData is Map<String, dynamic> && responseData["TxIsVerified"] == "true") {
          return TkmTransactionTransactionResult(success: true, message: "Transaction verified successfully");
        } else {
          return TkmTransactionTransactionResult(success: false, message: "Transaction failed: TxIsVerified is not true.");
        }
      } else {
        // Handle errors by returning a message with the status code and status message.
        return TkmTransactionTransactionResult(success: false, message: "Error: ${response.statusCode} - ${response.statusMessage}");
      }
    } catch (e) {
      // Catch any unexpected errors and return a failure message.
      return TkmTransactionTransactionResult(success: false, message: "An unexpected error occurred: ${e.toString()}");
    }
  }

  // Method to get the list of staking nodes.
  Future<List<TkmWalletStakingNode>> getStakingNodeList() async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getStakingNodeList; // Endpoint to fetch staking nodes.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);           // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);        // Get the HTTP method.

    try {
      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );

      // Send the request to get the staking node list.
      var response = await _dicClient.request(urlCall, options: options);

      // If successful, parse and return the list of nodes.
      if (response.statusCode == 200) {
        var responseData = TkmWalletListNodeResponse.fromJson(response.data);
        var listNode = responseData.nodeList;
        return listNode ?? [];  // Return the list or an empty list if null.
      }

      return [];
    } catch (ex) {
      return [];  // Return an empty list on failure.
    }
  }

  // Method to retrieve the QTesla address of a node.
  Future<String?> retriveNodeQteslaAddress({required String shortAddressNode}) async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.retiveQtelsaAddress; // Endpoint to retrieve QTesla address.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);            // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);         // Get the HTTP method.

    var urlWithParam = "$urlCall/$shortAddressNode";  // Append the node address to the URL.
    try {
      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );
      var response = await _dicClient.request(urlWithParam, options: options);

      // If successful, return the address.
      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          return responseData;
        }
      }

      return null;
    } catch (ex) {
      return null;  // Return null on failure.
    }
  }

  // Method to get the list of transactions for an address.
  Future<List<TkmWalletTransaction>> getTransactionList(
      {required String address,
        required TkmWalletEnumTypeTransaction typeTransaction,
        required int pageIndex,
        required int numberItemsForPage}) async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getTransactionList; // Endpoint to get the transaction list.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);           // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);        // Get the HTTP method.

    try {
      var urlWithParam = "$urlCall/$address";  // Append the address to the URL.

      Map<String, dynamic>? queryParameters;   // Define query parameters if needed.

      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );

      var response = await _dicClient.request(urlWithParam, options: options, queryParameters: queryParameters);

      // If successful, parse and return the list of transactions.
      if (response.statusCode == 200) {
        List<TkmWalletTransaction> transactions = TkmWalletTransaction.fromJsonList(response.data);
        return transactions ?? [];
      }

      return [];
    } catch (ex) {
      return [];  // Return an empty list on failure.
    }
  }

  // Method to get the balance of a wallet.
  Future<TkmWalletBalance?> getBalance({required String address}) async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getBalance;  // Endpoint to get the balance.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);    // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint); // Get the HTTP method.

    var urlWithParam = "$urlCall/$address";  // Append the address to the URL.
    try {
      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );
      var response = await _dicClient.request(urlWithParam, options: options);

      // If successful, parse and return the balance.
      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          return TkmWalletBalance.fromJson(responseData);
        }
      }

      return null;
    } catch (ex) {
      return null;  // Return null on failure.
    }
  }

  // Method to get the list of currencies.
  Future<List<TkmWalletCurrency>> getCurrencyList() async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getBalance;  // Endpoint to get the currency list.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);    // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint); // Get the HTTP method.

    try {
      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );
      var response = await _dicClient.request(urlCall, options: options);

      // If successful, parse and return the list of currencies.
      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          List<TkmWalletCurrency> currencies = TkmWalletCurrency.fromJsonList(response.data);
          return currencies ?? [];
        }
      }

      return [];
    } catch (ex) {
      return [];  // Return an empty list on failure.
    }
  }

  // Method to get the blockchain settings.
  Future<TkmWalletBlockchainSettings?> getSettingsBlockchain() async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getBalance;  // Endpoint to get the blockchain settings.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);    // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint); // Get the HTTP method.

    try {
      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );
      var response = await _dicClient.request(urlCall, options: options);

      // If successful, parse and return the blockchain settings.
      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          return TkmWalletBlockchainSettings.fromJson(responseData);
        }
      }

      return null;
    } catch (ex) {
      return null;  // Return null on failure.
    }
  }

  // Method to get the currencies exchange rates.
  Future<TkmWalletCurrenciesChange?> getCurrenciesExchangeRate() async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getCurrenciesChange;  // Endpoint to get the exchange rates.
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);    // Get the full URL for the endpoint.
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint); // Get the HTTP method.

    try {
      var options = Options(
        method: methodCall.name,  // Specify the HTTP method.
      );
      var response = await _dicClient.request(urlCall, options: options);

      // If successful, parse and return the exchange rates.
      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          TkmWalletCurrenciesChange exchangeRates = TkmWalletCurrenciesChange.fromJson(responseData);
          return exchangeRates;
        }
      }

      return null;
    } catch (ex) {
      return null;  // Return an empty list on failure.
    }
  }
}
