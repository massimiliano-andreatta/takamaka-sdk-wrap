import 'package:takamaka_sdk_wrap/models/messages/tkm_message_action.dart';
import 'package:takamaka_sdk_wrap/models/messages/tkm_message_address.dart';

class TkmPayRequestAction extends TkmMessageAction {
  final TkmMessageAddress to;
  final BigInt? greenValueNanoTkg;
  final BigInt? redValueNanoTkr;
  final String? message;

  TkmPayRequestAction({
    required this.to,
    required this.greenValueNanoTkg,
    required this.redValueNanoTkr,
    required this.message,
  }) : super(
    date: null,
    from: null,
    textMessage: message,
    to: to,
    green: greenValueNanoTkg,
    red: redValueNanoTkr,
    encodedWallet: null,
  );

  @override
  String toString() {
    return 'PayRequestAction{to: $to, greenValueNanoTkg: $greenValueNanoTkg, redValueNanoTkr: $redValueNanoTkr, message: $message}';
  }
}
