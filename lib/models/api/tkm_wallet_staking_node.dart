class TkmWalletStakingNode {
  int? activeStake;
  String? address;
  String? alias;
  int? blocksSubmitted;
  int? epochEvaluated;
  int? holders;
  String? identicon;
  int? nrOverflow;
  String? shortAddress;
  int? slotsAssigned;
  int? stakeToActivation;
  int? stakeUntilPenalty;

  TkmWalletStakingNode({
    this.activeStake,
    this.address,
    this.alias,
    this.blocksSubmitted,
    this.epochEvaluated,
    this.holders,
    this.identicon,
    this.nrOverflow,
    this.shortAddress,
    this.slotsAssigned,
    this.stakeToActivation,
    this.stakeUntilPenalty,
  });

  TkmWalletStakingNode.fromJson(Map<String, dynamic> json)
      : activeStake = json['activeStake'],
        address = json['address'],
        alias = json['alias'],
        blocksSubmitted = json['blocksSubmitted'],
        epochEvaluated = json['epochEvaluated'],
        holders = json['holders'],
        identicon = json['identicon'],
        nrOverflow = json['nrOverflow'],
        shortAddress = json['shortAddress'],
        slotsAssigned = json['slotsAssigned'],
        stakeToActivation = json['stakeToActivation'],
        stakeUntilPenalty = json['stakeUntilPenalty'];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['activeStake'] = activeStake;
    data['address'] = address;
    data['alias'] = alias;
    data['blocksSubmitted'] = blocksSubmitted;
    data['epochEvaluated'] = epochEvaluated;
    data['holders'] = holders;
    data['identicon'] = identicon;
    data['nrOverflow'] = nrOverflow;
    data['shortAddress'] = shortAddress;
    data['slotsAssigned'] = slotsAssigned;
    data['stakeToActivation'] = stakeToActivation;
    data['stakeUntilPenalty'] = stakeUntilPenalty;
    return data;
  }
}