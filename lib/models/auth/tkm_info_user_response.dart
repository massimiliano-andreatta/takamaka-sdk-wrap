class TkmInfoUserResponse {
  TkmInfoUserResponse({
    required this.address,
    required this.name,
    required this.phone,
    required this.surname,
  });

  final String? address;
  final String? name;
  final String? phone;
  final String? surname;

  factory TkmInfoUserResponse.fromJson(Map<String, dynamic> json){
    return TkmInfoUserResponse(
      address: json["address"],
      name: json["name"],
      phone: json["phone"],
      surname: json["surname"],
    );
  }

  Map<String, dynamic> toJson() => {
    "address": address,
    "name": name,
    "phone": phone,
    "surname": surname,
  };

  @override
  String toString(){
    return "$address, $name, $phone, $surname, ";
  }
}
