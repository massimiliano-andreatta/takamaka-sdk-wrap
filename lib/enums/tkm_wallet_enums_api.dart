library takamaka_sdk_wrap;

import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';

import '../models/api/tkm_wallet_api_endpoint.dart';

enum TkmWalletEnumApiEndpoints {
  login,
  sendTransaction,
  retiveQtelsaAddress,
  getStakingNodeList,
  getTransactionList,
  getAcceptedBets,
  getBalance,
  getCurrencyList,
  getSettingsBlockchain,
  getCurrenciesChange,
  searchTransactions
}

enum TkmWalletEnumEnvironments {
  test('https://test.takamaka.org'),
  production('https://takamaka.io');

  final String baseUrl;

  const TkmWalletEnumEnvironments(this.baseUrl);

  String getDomain() {
    return baseUrl;
  }

  String getFullApiUrl(TkmWalletEnumApiEndpoints endpoint) {
    final endpointDetails = endpoint.details;
    return '$baseUrl${endpointDetails.path}';
  }

  HttpMethods getHttpMethod(TkmWalletEnumApiEndpoints endpoint) {
    return endpoint.details.method;
  }
}

extension TkmWalletEnumApiEndpointsExtension on TkmWalletEnumApiEndpoints {
  TkmWalletApiEndpoint get details {
    switch (this) {
      case TkmWalletEnumApiEndpoints.login:
        return const TkmWalletApiEndpoint('/api/a4l/login', HttpMethods.POST);
      case TkmWalletEnumApiEndpoints.sendTransaction:
        return const TkmWalletApiEndpoint('/api/v1/transaction', HttpMethods.POST);
      case TkmWalletEnumApiEndpoints.retiveQtelsaAddress:
        return const TkmWalletApiEndpoint('/api/v1/bookmark/retrieve', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getStakingNodeList:
        return const TkmWalletApiEndpoint('/api/v2/node/list', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getAcceptedBets:
        return const TkmWalletApiEndpoint('/api/acceptedbets', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getTransactionList:
        return const TkmWalletApiEndpoint('/api/search/fromto', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getBalance:
        return const TkmWalletApiEndpoint('/api/v1/balance', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getCurrencyList:
        return const TkmWalletApiEndpoint('/api/v1/currencies/list', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getSettingsBlockchain:
        return const TkmWalletApiEndpoint('/api/tkmsettings', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.getCurrenciesChange:
        return const TkmWalletApiEndpoint('/api/v1/currencies/change', HttpMethods.GET);
      case TkmWalletEnumApiEndpoints.searchTransactions:
        return const TkmWalletApiEndpoint('/api/v1/transactions/search', HttpMethods.GET);
    }
  }
}
