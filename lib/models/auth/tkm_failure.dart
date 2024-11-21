import 'dart:ffi';

import 'package:equatable/equatable.dart';

abstract class TkmFailure extends Equatable {

  late final bool retry = false;
  late final bool exit = false;
  late String message = "";

  @override
  List<Object> get props => [];
}

class TkmGenericFailure extends TkmFailure {
  @override
  final String message = "Generic error";
  TkmGenericFailure(String? message){
    this.message = message ?? "Generic error";
  }
}

class TkmServerFailure extends TkmFailure {
  ServerFailure(String message) {
    this.message = message;
  }
}

class TkmCacheFailure extends TkmFailure {
  final String message;
  TkmCacheFailure(this.message);
}

class TkmNetworkFailure extends TkmFailure {
  final String message;
  TkmNetworkFailure(this.message);
}

class TkmInvalidInputFailure extends TkmFailure {
  final String message;
  TkmInvalidInputFailure(this.message);
}

class TkmAuthenticationFailure extends TkmFailure {
  final String message;
  TkmAuthenticationFailure(this.message);
}
