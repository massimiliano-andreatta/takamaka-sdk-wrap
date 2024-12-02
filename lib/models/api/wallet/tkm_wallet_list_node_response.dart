library takamaka_sdk_wrap;

import 'package:takamaka_sdk_wrap/models/api/wallet/tkm_wallet_staking_node.dart';

class TkmWalletListNodeResponse {
  String? dateUpdate;
  List<TkmWalletStakingNode>? nodeList;

  TkmWalletListNodeResponse({this.dateUpdate, this.nodeList});

  TkmWalletListNodeResponse.fromJson(Map<String, dynamic> json)
      : dateUpdate = json['date_update'],
        nodeList = (json['node_list'] as List?)?.map((v) => TkmWalletStakingNode.fromJson(v)).toList();

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['date_update'] = dateUpdate;
    if (nodeList != null) {
      data['node_list'] = nodeList!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
