library takamaka_sdk_wrap;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'dart:convert';
import 'package:takamaka_sdk_wrap/enums/tkm_wallet_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_failure.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_info_user_response.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_list_address_response.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_login_request.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_login_response.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_notification_response.dart';
import 'package:takamaka_sdk_wrap/models/auth/tkm_sync_address_response.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_address.dart';

class TkmWalletAuthClientApi {
  final Dio _dicClient;
  final TkmWalletEnumEnvironments _currentEnv;

  TkmWalletAuthClientApi({required Dio dicClient, required TkmWalletEnumEnvironments currentEnv})
      : _dicClient = dicClient,
        _currentEnv = currentEnv;


  Future<Either<TkmFailure, List<TkmNotificationResponse>>> authGetNotifications(String? token) async {
    try {
      const enuEndpoint = TkmWalletEnumApiEndpoints.authGetInfoUser;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      var headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers["Authorization"] = "Bearer $token";
      }

      var response = await _dicClient.request(
        urlCall,
        options: Options(method: methodCall.name, headers: headers),
      );

      switch (response.statusCode) {
        case 200:
          List<TkmNotificationResponse> notifications = (response.data as List)
              .map((e) => TkmNotificationResponse.fromJson(e))
              .toList();
          return Right(notifications);
        case 401:
          return Left(TkmAuthenticationFailure('Not authentication: ${response.statusCode}'));
        case 500:
          return Left(TkmServerFailure());
        default:
          return Left(TkmGenericFailure(null));
      }
    } catch (error) {
      return Left(TkmGenericFailure(error.toString()));
    }
  }

  Future<Either<TkmFailure, TkmInfoUserResponse>> getInfoUser(String token) async {
    try {
      const enuEndpoint = TkmWalletEnumApiEndpoints.authGetInfoUser;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      var headers = {'Authorization': "Bearer " + token};

      var response = await _dicClient.request(
        urlCall,
        options: Options(method: methodCall.name, headers: headers),
      );

      switch (response.statusCode) {
        case 200:
          final infoUserResponse = TkmInfoUserResponse.fromJson(response.data);
          return Right(infoUserResponse);
        case 401:
          return Left(TkmAuthenticationFailure('Not authentication: ${response.statusCode}'));
        case 500:
          return Left(TkmServerFailure());
        default:
          return Left(TkmGenericFailure(null));
      }
    } catch (error) {
      return Left(TkmGenericFailure(error.toString()));
    }
  }

  Future<Either<TkmFailure, TkmSyncAddressResponse>> syncAddress(String token, TkmWalletAddress address) async {
    try {
      const enuEndpoint = TkmWalletEnumApiEndpoints.authSyncAddress;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      var headers = {'Authorization': "Bearer " + token};

      var transactionBlobText = await address.createTransactionBlobSyncAddress();

      var data = transactionBlobText.toJson();

      var response = await _dicClient.request(urlCall, options: Options(method: methodCall.name, headers: headers), data: data);

      switch (response.statusCode) {
        case 200:
          final syncAddressResponse = TkmSyncAddressResponse.fromJson(response.data);
          return Right(syncAddressResponse);
        case 401:
          return Left(TkmAuthenticationFailure('Not authentication: ${response.statusCode}'));
        case 500:
          return Left(TkmServerFailure());
        default:
          return Left(TkmGenericFailure(null));
      }
    } catch (error) {
      return Left(TkmGenericFailure(error.toString()));
    }
  }

  Future<Either<TkmFailure, List<TkmAddressResponse>>> getListAddressRegisterForUser(String token) async {
    try {
      const enuEndpoint = TkmWalletEnumApiEndpoints.authGetListAddressRegisterForUser;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      var headers = {'Authorization': "Bearer " + token};

      var response = await _dicClient.request(
        urlCall,
        options: Options(method: methodCall.name, headers: headers),
      );

      switch (response.statusCode) {
        case 200:
          List<TkmAddressResponse> addresses = (response.data as List)
              .map((e) => TkmAddressResponse.fromJson(e))
              .toList();
          return Right(addresses);
        case 401:
          return Left(TkmAuthenticationFailure('Not authentication: ${response.statusCode}'));
        case 500:
          return Left(TkmServerFailure());
        default:
          return Left(TkmGenericFailure(null));
      }
    } catch (error) {
      return Left(TkmGenericFailure(error.toString()));
    }
  }

  Future<Either<TkmFailure, TkmLoginResponse>> login(TkmLoginRequest request) async {
    try {
      const enuEndpoint = TkmWalletEnumApiEndpoints.authLogin;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      var response = await _dicClient.request(
        urlCall,
        options: Options(
          method: methodCall.name,
        ),
        data: request.toJson(),
      );

      switch (response.statusCode) {
        case 200:
          final loginResponse = TkmLoginResponse.fromJson(response.data);
          return Right(loginResponse);
        case 401:
          return Left(TkmAuthenticationFailure('Login failed with status: ${response.statusCode}'));
        case 500:
          return Left(TkmServerFailure());
        default:
          return Left(TkmGenericFailure(null));
      }
    } catch (error) {
      return Left(TkmGenericFailure(error.toString()));
    }
  }

  Future<Either<TkmFailure, TkmLoginResponse>> refreshToken(
      String refreshToken,
      String username,
      String deviceId,
      ) async {
    try {
      const enuEndpoint = TkmWalletEnumApiEndpoints.authRefreshToken;
      var urlCall = _currentEnv.getFullApiUrl(enuEndpoint);
      var methodCall = _currentEnv.getHttpMethod(enuEndpoint);

      // Calcolo del timestamp
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      // Concatenazione della stringa da firmare
      final stringToSign = '$username$deviceId$timestamp';

      // Generazione della firma
      final secretKey = utf8.encode(refreshToken); // Usa `refreshToken` come chiave
      final bytesToSign = utf8.encode(stringToSign);
      final signature = Hmac(sha256, secretKey).convert(bytesToSign).toString();

      // Creazione del corpo della richiesta
      final requestBody = {
        "username": username,
        "device-id": deviceId,
        "timestamp": timestamp,
        "signature": signature,
      };

      // Invio della richiesta
      var response = await _dicClient.request(
        urlCall,
        data: requestBody,
        options: Options(
          method: methodCall.name,
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      // Gestione della risposta
      switch (response.statusCode) {
        case 200:
          final refreshResponse = TkmLoginResponse.fromJson(response.data);
          refreshResponse.refreshToken = refreshToken;

          return Right(refreshResponse);
        case 401:
          return Left(TkmAuthenticationFailure('Not authentication: ${response.statusCode}'));
        case 500:
          return Left(TkmServerFailure());
        default:
          return Left(TkmGenericFailure(null));
      }
    } catch (error) {
      return Left(TkmGenericFailure(error.toString()));
    }
  }

}
