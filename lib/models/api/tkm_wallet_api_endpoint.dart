library takamaka_sdk_wrap;

import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';

class TkmWalletApiEndpoint {
  final String path;
  final HttpMethods method;

  const TkmWalletApiEndpoint(this.path, this.method);
}
