// ignore_for_file: must_be_immutable

import 'dart:ffi';

import 'package:equatable/equatable.dart';

abstract class TkmFailure extends Equatable {
  late final bool retry = false;
  late final bool exit = false;
  late String message = "";
  late int code = 0;

  @override
  List<Object> get props => [];
}

class TkmGenericFailure extends TkmFailure {
  @override
  final String message = "Generic error";
  final int code = 500;
  TkmGenericFailure(String? message, int? code) {
    this.message = message ?? "Generic error";
    this.code = code ?? 500;
  }
}

class TkmServerFailure extends TkmFailure {
  ServerFailure(String message, int code) {
    this.message = message;
    this.code = code;
  }
}

class TkmCacheFailure extends TkmFailure {
  final String message;
  TkmCacheFailure(this.message) {
    code = 404;
  }
}

class TkmNetworkFailure extends TkmFailure {
  final String message;
  TkmNetworkFailure(this.message) {
    code = 503;
  }
}

class TkmInvalidInputFailure extends TkmFailure {
  final String message;
  TkmInvalidInputFailure(this.message) {
    code = 400;
  }
}

class TkmAuthenticationFailure extends TkmFailure {
  final String message;
  TkmAuthenticationFailure(this.message) {
    code = 401;
  }
}
