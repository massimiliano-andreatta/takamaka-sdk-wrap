import 'package:takamaka_sdk_wrap/enums/tkm_message_acction_type.dart';
import 'package:takamaka_sdk_wrap/models/messages/tkm_base_bean.dart';

import '../../models/messages/tkm_pay_request_action.dart';

class TkmSimpleRequestModels {
  static TkmBaseBean getSimplePayRequestV10(String to, BigInt greenValueNanoTkg, BigInt redValueNanoTkr, String message) {
    return TkmBaseBean(
      version: "1.0",
      messageAction: TkmPayRequestAction(SimpleRequestHelper.getAddress(to), greenValueNanoTkg, redValueNanoTkr, message),
      typeOfAction: TkmMessageActionType.requestPay.shortCode,
      typeOfSignature: null,
      signature: null,
      encryptedMessageAction: null,
    );
  }
}
