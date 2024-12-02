library takamaka_sdk_wrap;

import 'package:dio/dio.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_wallet_enums_api.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_chat_client_api.dart';

class TkmChatService {
  // Initialize the API client for wallet interactions, targeting the test environment
  static late TkmChatClientApi _clientApi;

  TkmChatService({required TkmWalletEnumEnvironments currentEnv}) {
    _clientApi = TkmChatClientApi(currentEnv: currentEnv, dicClient: Dio());
  }
}
