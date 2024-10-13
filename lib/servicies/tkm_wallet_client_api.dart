library takamaka_sdk_wrap;

import 'package:dio/dio.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';

import '../enums/tkm_wallet_enum_type_transaction.dart';
import '../enums/tkm_wallet_enums_api.dart';
import '../models/api/tkm_wallet_balance.dart';
import '../models/api/tkm_wallet_list_node_response.dart';
import '../models/api/tkm_wallet_staking_node.dart';
import '../models/api/tkm_wallet_transaction_response.dart';
import '../models/api/tkm_wallet_transaction_result.dart';

class TransactionResult {
  final bool success;
  final String message;

  TransactionResult({required this.success, required this.message});
}

class TkmWalletClientApi {
  final Dio _dicClient;
  final TkmWalletEnumEnvironments _currentEnv;

  TkmWalletClientApi({required Dio dicClient, required TkmWalletEnumEnvironments currentEnv})
      : _dicClient = dicClient,
        _currentEnv = currentEnv;

  Future<TkmTransactionTransactionResult> sendingTransaction({required TransactionInput transactionSend}) async {
    try {
      var tx = transactionSend.toJson();
      var data = FormData.fromMap(tx);

      var enuEndpoint = TkmWalletEnumApiEndpoints.sendTransaction;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      var response = await _dicClient.request(
        urlCall,
        options: Options(
          method: methodCall.toString(),
        ),
        data: data,
      );

      if (response.statusCode == 200) {
        var responseData = response.data;

        if (responseData is Map<String, dynamic> && responseData["TxIsVerified"] == "true") {
          return TkmTransactionTransactionResult(
              success: true,
              message: "Transaction verified successfully"
          );
        } else {
          return TkmTransactionTransactionResult(
              success: false,
              message: "Transaction failed: TxIsVerified is not true."
          );
        }
      } else {
        return TkmTransactionTransactionResult(
            success: false,
            message: "Error: ${response.statusCode} - ${response.statusMessage}"
        );
      }
    }  catch (e) {
      return TkmTransactionTransactionResult(
          success: false,
          message: "An unexpected error occurred: ${e.toString()}"
      );
    }
  }

  Future<List<TkmWalletStakingNode>> getStakingNodeList() async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getStakingNodeList;
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

    try {
      var options = Options(
        method: methodCall.name,
      );

      var response = await _dicClient.request(urlCall, options: options);

      if (response.statusCode == 200) {
        var responseData = TkmWalletListNodeResponse.fromJson(response.data) ;
        var listNode = responseData.nodeList;
        return listNode ?? [];
      }

      return [];
    } catch (ex) {
      return [];
    }

  }

  Future<String?> retriveNodeQteslaAddress({ required String shortAddressNode}) async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.retiveQtelsaAddress;
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

    var urlWithParam = "$urlCall/$shortAddressNode";
    try {
      var options = Options(
        method: methodCall.name,
      );
      var response = await _dicClient.request(
          urlWithParam,
          options: options
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          return responseData;
        }
      }

      return null;
    } catch (ex) {
      return null;
    }

  }

  Future<List<TkmWalletTransaction>> getTransactionList({required String address, required TkmWalletEnumTypeTransaction typeTransaction, required int pageIndex, required int numberItemsForPage}) async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getTransactionList;
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

    try {
      var urlWithParam = "$urlCall/$address";

      Map<String, dynamic>? queryParameters;

      var options = Options(
        method: methodCall.name,
      );

      var response = await _dicClient.request(urlWithParam, options:options, queryParameters:queryParameters);

      if (response.statusCode == 200) {
        List<TkmWalletTransaction> transactions = TkmWalletTransaction.fromJsonList(response.data);
        return transactions ?? [];
      }

      return [];
    } catch (ex) {
      return [];
    }

  }

  Future<TkmWalletBalance?> getBalance({required String address}) async {
    var enuEndpoint = TkmWalletEnumApiEndpoints.getBalance;
    var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
    var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

    var urlWithParam = "$urlCall/$address";
    try {
      var options = Options(
        method: methodCall.name,
      );
      var response = await _dicClient.request(
          urlWithParam,
          options: options
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData) {
          return TkmWalletBalance.fromJson(responseData);
        }
      }

      return null;
    } catch (ex) {
      return null;
    }

  }

}
