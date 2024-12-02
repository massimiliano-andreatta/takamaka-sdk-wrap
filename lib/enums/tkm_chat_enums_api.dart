library takamaka_sdk_wrap;

import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/models/api/wallet/tkm_wallet_api_endpoint.dart';

enum TkmChatEnumApiEndpoints {
  nonce,
}

enum TkmChatEnumEnvironments {
  test('https://chat.test.takamaka.org'),
  production('https://takamaka.io');

  final String baseUrl;

  const TkmChatEnumEnvironments(this.baseUrl);

  String getDomain() {
    return baseUrl;
  }

  String getFullApiUrl(TkmChatEnumApiEndpoints endpoint) {
    final endpointDetails = endpoint.details;
    return '$baseUrl${endpointDetails.path}';
  }

  HttpMethods getHttpMethod(TkmChatEnumApiEndpoints endpoint) {
    return endpoint.details.method;
  }
}

extension TkmChatEnumApiEndpointsExtension on TkmChatEnumApiEndpoints {
  TkmChatApiEndpoint get details {
    switch (this) {
      case TkmChatEnumApiEndpoints.nonce:
        return const TkmChatApiEndpoint('/nonce', HttpMethods.POST);

    }
  }
}
