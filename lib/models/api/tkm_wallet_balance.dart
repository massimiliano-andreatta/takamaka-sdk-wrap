library takamaka_sdk_wrap;

class TkmWalletBalance {
  String? _address;
  int? _greenBalance;
  int? _redBalance;
  int? _greenPenalty;
  int? _redPenalty;
  int? _penaltySlots;
  String? _generatorSith;

  TkmWalletBalance(
      {String? address,
        int? greenBalance,
        int? redBalance,
        int? greenPenalty,
        int? redPenalty,
        int? penaltySlots,
        String? generatorSith}) {
    if (address != null) {
      this._address = address;
    }
    if (greenBalance != null) {
      this._greenBalance = greenBalance;
    }
    if (redBalance != null) {
      this._redBalance = redBalance;
    }
    if (greenPenalty != null) {
      this._greenPenalty = greenPenalty;
    }
    if (redPenalty != null) {
      this._redPenalty = redPenalty;
    }
    if (penaltySlots != null) {
      this._penaltySlots = penaltySlots;
    }
    if (generatorSith != null) {
      this._generatorSith = generatorSith;
    }
  }

  String? get address => _address;
  set address(String? address) => _address = address;
  int? get greenBalance => _greenBalance;
  set greenBalance(int? greenBalance) => _greenBalance = greenBalance;
  int? get redBalance => _redBalance;
  set redBalance(int? redBalance) => _redBalance = redBalance;
  int? get greenPenalty => _greenPenalty;
  set greenPenalty(int? greenPenalty) => _greenPenalty = greenPenalty;
  int? get redPenalty => _redPenalty;
  set redPenalty(int? redPenalty) => _redPenalty = redPenalty;
  int? get penaltySlots => _penaltySlots;
  set penaltySlots(int? penaltySlots) => _penaltySlots = penaltySlots;
  String? get generatorSith => _generatorSith;
  set generatorSith(String? generatorSith) => _generatorSith = generatorSith;

  TkmWalletBalance.fromJson(Map<String, dynamic> json) {
    _address = json['address'];
    _greenBalance = json['greenBalance'];
    _redBalance = json['redBalance'];
    _greenPenalty = json['greenPenalty'];
    _redPenalty = json['redPenalty'];
    _penaltySlots = json['penaltySlots'];
    _generatorSith = json['generatorSith'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['address'] = this._address;
    data['greenBalance'] = this._greenBalance;
    data['redBalance'] = this._redBalance;
    data['greenPenalty'] = this._greenPenalty;
    data['redPenalty'] = this._redPenalty;
    data['penaltySlots'] = this._penaltySlots;
    data['generatorSith'] = this._generatorSith;
    return data;
  }
}
