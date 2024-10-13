import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cryptography/cryptography.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:pointycastle/digests/sha3.dart';

class TkmWalletAddress {
  /// Private variable containing the wallet's seed
  late final String _seed;

  /// Wallet index for key derivation
  late final int _index;

  /// Wallet name assigned by the user
  late String _walletName;

  /// Data for the Identicon icon of the wallet
  ByteBuffer? _identiconData;

  /// Wallet address
  late final String _address;

  /// CRC code of the address
  String? _crc;

  /// Display name of the wallet (used in the UI)
  String _name = "";

  /// Primary color generated from the address
  Color? _primaryColor;

  /// Indicates if the wallet is marked as favorite
  bool _favorite = false;

  /// Indicates if the wallet is visible in the list
  bool _visible = true;

  /// Wallet key pair (public and private)
  late final SimpleKeyPair _keypair;

  /// Wallet constructor: receives seed, index, and wallet name
  TkmWalletAddress(this._seed, this._index, this._walletName) {
    /// Default name if an explicit name is not provided
    _name = _walletName.isEmpty ? "Address $_index" : _walletName;
  }

  /// Returns the wallet's "favorite" status
  bool get favorite => _favorite;

  /// Sets the wallet's "favorite" status
  set favorite(bool value) => _favorite = value;

  /// Returns the wallet index
  int get index => _index;

  /// Returns the wallet's Identicon data
  ByteBuffer? get identiconData => _identiconData;

  /// Returns the wallet address
  String get address => _address;

  /// Returns the CRC of the address
  String? get crc => _crc;

  /// Returns the wallet's primary color
  Color? get primaryColor => _primaryColor;

  /// Returns the display name of the wallet
  String get name => _name;

  /// Sets the wallet's display name
  set name(String value) => _name = value.isEmpty ? "Address $_index" : value;

  /// Returns the wallet's visibility status
  bool get visible => _visible;

  /// Sets the wallet's visibility
  void setVisible(bool visible) => _visible = visible;

  /// Initializes the wallet: generates key and address
  Future<void> initialize() async {
    try {
      _keypair = await WalletUtils.getNewKeypairED25519(_seed, index: _index);
      _address = await WalletUtils.getTakamakaAddress(_keypair);
      _crc = await WalletUtils.getCrc32(_keypair);
      _identiconData = (await WalletUtils.testBitMap(_address)).buffer;

      /// Generating the primary color from the hashed address
      final String hex = CryptoMisc.hash256ToHex(_address);
      _primaryColor = _colorFromHex(hex.substring(58, 64));
    } catch (e) {
      /// Handling errors during wallet initialization
      print("Error during wallet initialization: $e");
    }
  }

  /// Converts the wallet object into a JSON representation
  Map<String, dynamic> toJson() {
    return {
      'seed': _seed,
      'index': _index,
      'name': _name,
      'walletName': _walletName,
      'favorite': _favorite, // Include the favorite flag in JSON
      'visible': _visible,   // Include the visibility flag in JSON
    };
  }

  /// Factory constructor to create a wallet object from a JSON representation
  static Future<TkmWalletAddress> fromJson(Map<String, dynamic> json) async {
    TkmWalletAddress walletObj = TkmWalletAddress(
      json['seed'],
      json['index'],
      json['walletName'],
    );

    // Restore the "favorite" and "visible" flags from the JSON
    walletObj._favorite = json['favorite'] ?? false; // Set the "favorite" status from JSON
    walletObj._visible = json['visible'] ?? true;    // Set the visibility from JSON
    walletObj._name = json['name'] ?? "Address ${json['index']}";

    // Asynchronously initialize the wallet
    await walletObj.initialize();

    return walletObj;
  }

  /// Creates a color from a hexadecimal string
  static Color _colorFromHex(String hex) {
    return Color.fromARGB(255, _hexToInt(hex.substring(0, 2)), _hexToInt(hex.substring(2, 4)), _hexToInt(hex.substring(4, 6)));
  }

  /// Helper to convert a hexadecimal substring to an integer
  static int _hexToInt(String hex) => int.parse(hex, radix: 16);

  /// Creates a "stake undo" transaction
  Future<TransactionBean> createTransactionStakeUndo() async {
    final transactionTime = TKmTK.getTransactionTime();
    final itb = BuilderItb.stakeUndo(_address, "Stake undo", transactionTime);

    return await _createGenericTransaction(itb);
  }

  /// Creates a "stake add" transaction with provided parameters
  Future<TransactionBean> createTransactionStakeAdd({
    required String qteslaAddress,
    required BigInt bigIntValue,
    required String message,
  }) async {
    final transactionTime = TKmTK.getTransactionTime();
    final itb = BuilderItb.stake(_address, qteslaAddress, bigIntValue, message, transactionTime);

    return await _createGenericTransaction(itb);
  }

  /// Creates a text message transaction
  Future<TransactionBean> createTransactionBlobText({required String message}) async {
    final transactionTime = TKmTK.getTransactionTime();
    final itb = BuilderItb.blob(_address, message, transactionTime);

    return await _createGenericTransaction(itb);
  }

  /// Creates a transaction with the hash of a file
  Future<TransactionBean> createTransactionBlobHash({required File file}) async {
    try {
      final bytes = await file.readAsBytes();
      final sha3Digest = SHA3Digest(256);
      final hash = sha3Digest.process(Uint8List.fromList(bytes));
      final b64UrlHash = base64UrlEncode(hash);

      final transactionTime = TKmTK.getTransactionTime();
      final itb = BuilderItb.blob(_address, b64UrlHash, transactionTime);

      return await _createGenericTransaction(itb);
    } catch (e) {
      /// Handling errors during file reading or hashing
      print("Error creating transaction with file hash: $e");
      rethrow;
    }
  }

  /// Creates a payment transaction in TKG (Takamaka Green)
  Future<TransactionBean> createTransactionPayTkg({
    required String to,
    required BigInt bigIntValue,
    required String message,
  }) async {
    final transactionTime = TKmTK.getTransactionTime();
    final itb = BuilderItb.pay(_address, to, bigIntValue, null, message, transactionTime);

    return await _createGenericTransaction(itb);
  }

  /// Creates a payment transaction in TKR (Takamaka Red)
  Future<TransactionBean> createTransactionPayTkr({
    required String to,
    required BigInt bigIntValue,
    required String message,
  }) async {
    final transactionTime = TKmTK.getTransactionTime();
    final itb = BuilderItb.pay(_address, to, null, bigIntValue, message, transactionTime);

    return await _createGenericTransaction(itb);
  }

  /// Helper function for generic transaction creation
  Future<TransactionBean> _createGenericTransaction(InternalTransactionBean itb) async {
    try {
      return await TkmWallet.createGenericTransaction(itb, _keypair, _address);
    } catch (e) {
      /// Handling errors during transaction creation
      print("Error creating transaction: $e");
      rethrow;
    }
  }

  Future<TransactionBox> verifyTransactionIntegrity(TransactionBean tb) async {
    String tbJson = jsonEncode(tb.toJson());
    TransactionBox transactionBox = await TkmWallet.verifyTransactionIntegrity(tbJson, _keypair);
    return transactionBox;
  }

  Future<FeeBean> calculateTransactionFee(TransactionBean tb) async {
    String tbJson = jsonEncode(tb.toJson());
    TransactionBox transactionBox = await TkmWallet.verifyTransactionIntegrity(tbJson, _keypair);
    FeeBean feeBean = TransactionFeeCalculator.getFeeBean(transactionBox);
    return feeBean;
  }

  Future<TransactionInput> prepareTransactionForSend(TransactionBean tb) async {
    String tbJson = jsonEncode(tb.toJson());
    String payHexBody = StringUtilities.convertToHex(tbJson);
    TransactionInput ti = TransactionInput(payHexBody);
    return ti;
  }
}
