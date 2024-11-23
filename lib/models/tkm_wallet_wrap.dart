library takamaka_sdk_wrap;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'tkm_wallet_address.dart';
import 'tkm_wallet_exceptions.dart';
import 'package:path/path.dart' as path;

class TkmWalletWrap {
  // Constants for wallet file extension and path
  static final String _walletExtension = ".wallet";
  static final String _walletPath = "wallets";

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
  TkmWalletWrap.restoreWithWords(this._walletName, this._password, this._generatedWordsPreInitWallet);

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
  Future<File> getFile() async {
    String separator = path.separator;
    String fullPath = _walletPath + separator + walletName + _walletExtension;
    return File(fullPath);
  }

  static Future<TkmWalletWrap> restoreFromKeyWords({required List<String> wordList, required String walletName, required String password}) async {
    var walletWrap = TkmWalletWrap.restoreWithWords(walletName, password, wordList);
    await walletWrap.initializeWallet();
    return walletWrap;
  }

  static Future<TkmWalletWrap> restoreWalletFromFile({required File walletFile, required String walletName, required String password}) async {
    String encriptedWallet = await FileSystemUtils.readFile(walletFile.path);
    String decriptedString = CryptoMisc.descryptWallet(encriptedWallet, password);

    dynamic a = jsonDecode(decriptedString);
    KeyBean kb = KeyBean.fromJson(a);

    var walletWrap = TkmWalletWrap.restoreFromKeyWords(walletName: walletName, password: password, wordList: kb.words.split(" "));
    return walletWrap;
  }

  // Method to initialize the wallet
  Future<void> initializeWallet() async {
    KeyBean kb;

    // If seed is not provided, generate new seed words and initialize the wallet
    if (_seed == null || _seed!.isEmpty) {
      if (_generatedWordsPreInitWallet.isEmpty) {
        _generatedWordsPreInitWallet = await WordsUtils.generateWords();
      }
    }

    if (_generatedWordsPreInitWallet.isNotEmpty && (_seed == null || _seed!.isEmpty)) {
      var concat = _generatedWordsPreInitWallet.join(" ");
      _seed = await WalletUtils.generateSeedPWH(_generatedWordsPreInitWallet);
      kb = KeyBean("0.1", "POWSEED", "Ed25519BC", _seed!, concat);
    }

    // If the wallet is successfully created, initialize the main wallet object
    if (_seed != null) {
      _hash = md5.convert(utf8.encode(_seed!)).toString();

      var addressMain = TkmWalletAddress(_seed!, 0, _walletName);
      await addressMain.initialize(); // Initialize the wallet
      _addresses.add(addressMain); // Add the wallet to the list
    }
  }

  Future<bool> removeAddress(TkmWalletAddress address) async {
    if (_seed != null) {
      if (address.index == 0) {
        throw InvalidIndexException("Index 0 is not allowed for remove address wallet.");
      }

      bool isIndexAlreadyUsed = _addresses.any((ele) => ele.index == address.index);
      if (isIndexAlreadyUsed == false) {
        throw DuplicateIndexException("Index ${address.index} is not already used by wallet.");
      }

      _addresses.remove(address);

      return true;
    }

    return false;
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
        throw DuplicateIndexException("Index $index is already used by wallet.");
      }

      // Create and initialize a new wallet with the provided index
      var address = TkmWalletAddress(_seed!, index, _walletName);
      await address.initialize(); // Initialize the wallet
      _addresses.add(address); // Add the new wallet to the list

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
      (json['addresses'] as List).map((walletJson) => TkmWalletAddress.fromJson(walletJson)).toList(),
    );

    // Return the constructed wallet wrapper object
    return TkmWalletWrap.withNameSeedAndAddresses(
      json['walletName'],
      json['seed'],
      addresses,
    );
  }
}
