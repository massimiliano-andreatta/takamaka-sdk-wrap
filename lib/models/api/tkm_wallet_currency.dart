library takamaka_sdk_wrap;

class TkmWalletCurrency {
  String? _name;
  String? _symbol;
  String? _acronym;

  TkmWalletCurrency({String? name, String? symbol, String? acronym}) {
    if (name != null) {
      this._name = name;
    }
    if (symbol != null) {
      this._symbol = symbol;
    }
    if (acronym != null) {
      this._acronym = acronym;
    }
  }

  String? get name => _name;
  set name(String? name) => _name = name;
  String? get symbol => _symbol;
  set symbol(String? symbol) => _symbol = symbol;
  String? get acronym => _acronym;
  set acronym(String? acronym) => _acronym = acronym;

  TkmWalletCurrency.fromJson(Map<String, dynamic> json) {
    _name = json['name'];
    _symbol = json['symbol'];
    _acronym = json['acronym'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this._name;
    data['symbol'] = this._symbol;
    data['acronym'] = this._acronym;
    return data;
  }

  static List<TkmWalletCurrency> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => TkmWalletCurrency.fromJson(json)).toList();
  }
}
