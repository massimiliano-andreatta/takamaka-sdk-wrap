library takamaka_sdk_wrap;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';

import 'tkm_wallet_address.dart';
import 'tkm_wallet_exceptions.dart';

class TkmWalletWrap {
  // Constants for wallet file extension and path
  final String _walletExtension = ".wallet";
  final String _walletPath = "wallets";

  // Variables for wallet name and password
  late final String _walletName;
  late final String? _password;

  late final String? _hash;

  // Seed and a list to store generated seed words before wallet initialization
  String? _seed;
  late List<String> _generatedWordsPreInitWallet = [];

  // List to store wallet objects
  final List<TkmWalletAddress> _addresses = [];

  // Constructor with wallet name and password
  TkmWalletWrap(this._walletName, this._password);

  // Constructor that accepts seed and pre-existing wallet objects
  TkmWalletWrap.withNameSeedAndAddresses(this._walletName, this._seed, List<TkmWalletAddress> addresses) {
    _addresses.addAll(addresses); // Add the passed wallets to the list
  }

  // Getter for the generated seed words before wallet initialization
  List<String> get generatedWordsInitWallet {
    return _generatedWordsPreInitWallet;
  }

  // Getter for the wallet name
  String get walletName {
    return _walletName;
  }

  String? get hash {
    return _hash;
  }

  // Getter for wallets that are visible
  List<TkmWalletAddress> get visibleAddresses {
    return _addresses.where((wallet) => wallet.visible).toList();
  }

  // Getter for all wallets
  List<TkmWalletAddress> get addresses {
    return _addresses;
  }

  // Async method to retrieve the wallet file
  Future<void> getFile() async {
    String encryptedWalletFile = await WalletUtils.readKeyFile(_walletPath, walletName, _walletExtension);
  }

  // Method to initialize the wallet
  Future<void> initializeWallet() async {
    Map<String, dynamic>? wallet;

    // If seed is not provided, generate new seed words and initialize the wallet
    if (_seed == null || _seed!.isEmpty) {
      _generatedWordsPreInitWallet = await WordsUtils.generateWords();

      // Create a new wallet with the generated seed words and password
      wallet = await WalletUtils.initWallet(
          _walletPath,            // Wallet directory path
          _walletName,            // Wallet name from the class variable
          _walletExtension,       // Wallet extension
          _password!,             // Provided password
          _generatedWordsPreInitWallet // Generated seed words
      );
    }

    // If the wallet is successfully created, initialize the main wallet object
    if (wallet != null) {
      _seed = wallet['seed'];

      if (_seed != null) {
        _hash = md5.convert(utf8.encode(_seed!)).toString();

        var addressMain = TkmWalletAddress(_seed!, 0, _walletName);
        addressMain.initialize(); // Initialize the wallet
        _addresses.add(addressMain); // Add the wallet to the list
      }
    }
  }

  // Method to add a new wallet address based on a given index
  Future<TkmWalletAddress?> addAddress(int index) async {
    // Ensure the seed is available
    if (_seed != null) {
      // Index 0 is reserved, throw an exception if trying to use it
      if (index == 0) {
        throw InvalidIndexException("Index 0 is not allowed for creating a wallet.");
      }

      // Check if the given index is already used by another wallet
      bool isIndexAlreadyUsed = _addresses.any((wallet) => wallet.index == index);

      // If the index is already used, throw a duplicate index exception
      if (isIndexAlreadyUsed) {
        throw DuplicateIndexException("Index $index is already used by another wallet.");
      }

      // Create and initialize a new wallet with the provided index
      var address = TkmWalletAddress(_seed!, index, _walletName);
      await address.initialize(); // Initialize the wallet
      _addresses.add(address);      // Add the new wallet to the list

      return address;
    }

    return null;
  }

  // Method to convert the wallet wrapper object into a JSON format
  Map<String, dynamic> toJson() {
    // Convert each wallet object to JSON
    List<Map<String, dynamic>> jsonList = _addresses.map((wallet) => wallet.toJson()).toList();
    return {
      'walletName': _walletName,
      'seed': _seed,
      'addresses': jsonList // List of wallets in JSON format
    };
  }

  // Factory constructor to create a wallet wrapper object from a JSON representation
  static Future<TkmWalletWrap> fromJson(Map<String, dynamic> json) async {
    // Create the wallet wrapper with seed and wallet objects from the JSON
    List<TkmWalletAddress> addresses = await Future.wait(
      (json['addresses'] as List)
          .map((walletJson) => TkmWalletAddress.fromJson(walletJson))
          .toList(),
    );

    // Return the constructed wallet wrapper object
    return TkmWalletWrap.withNameSeedAndAddresses(
      json['walletName'],
      json['seed'],
      addresses,
    );
  }

}
