library takamaka_sdk_wrap;

class TkmWalletCurrenciesChange {
  int? _tkgEur;
  int? _tkrEur;
  int? _tkgChf;
  int? _tkrChf;
  int? _tkgUsd;
  int? _tkrUsd;

  TkmWalletCurrenciesChange(
      {int? tkgEur,
        int? tkrEur,
        int? tkgChf,
        int? tkrChf,
        int? tkgUsd,
        int? tkrUsd}) {
    if (tkgEur != null) {
      this._tkgEur = tkgEur;
    }
    if (tkrEur != null) {
      this._tkrEur = tkrEur;
    }
    if (tkgChf != null) {
      this._tkgChf = tkgChf;
    }
    if (tkrChf != null) {
      this._tkrChf = tkrChf;
    }
    if (tkgUsd != null) {
      this._tkgUsd = tkgUsd;
    }
    if (tkrUsd != null) {
      this._tkrUsd = tkrUsd;
    }
  }

  int? get tkgEur => _tkgEur;
  set tkgEur(int? tkgEur) => _tkgEur = tkgEur;
  int? get tkrEur => _tkrEur;
  set tkrEur(int? tkrEur) => _tkrEur = tkrEur;
  int? get tkgChf => _tkgChf;
  set tkgChf(int? tkgChf) => _tkgChf = tkgChf;
  int? get tkrChf => _tkrChf;
  set tkrChf(int? tkrChf) => _tkrChf = tkrChf;
  int? get tkgUsd => _tkgUsd;
  set tkgUsd(int? tkgUsd) => _tkgUsd = tkgUsd;
  int? get tkrUsd => _tkrUsd;
  set tkrUsd(int? tkrUsd) => _tkrUsd = tkrUsd;

  TkmWalletCurrenciesChange.fromJson(Map<String, dynamic> json) {
    _tkgEur = json['tkg-eur'];
    _tkrEur = json['tkr-eur'];
    _tkgChf = json['tkg-chf'];
    _tkrChf = json['tkr-chf'];
    _tkgUsd = json['tkg-usd'];
    _tkrUsd = json['tkr-usd'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['tkg-eur'] = this._tkgEur;
    data['tkr-eur'] = this._tkrEur;
    data['tkg-chf'] = this._tkgChf;
    data['tkr-chf'] = this._tkrChf;
    data['tkg-usd'] = this._tkgUsd;
    data['tkr-usd'] = this._tkrUsd;
    return data;
  }
}
