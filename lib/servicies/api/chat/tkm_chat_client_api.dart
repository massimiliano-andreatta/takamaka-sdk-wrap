library takamaka_sdk_wrap;

import 'package:dio/dio.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_wallet_enums_api.dart';

class TkmChatClientApi {
  final Dio _dicClient;
  final TkmWalletEnumEnvironments _currentEnv;

  TkmChatClientApi({required Dio dicClient, required TkmWalletEnumEnvironments currentEnv})
      : _dicClient = dicClient,
        _currentEnv = currentEnv;


}
