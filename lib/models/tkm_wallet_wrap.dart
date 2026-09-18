library takamaka_sdk_wrap;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'tkm_wallet_address.dart';
import 'tkm_wallet_exceptions.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TkmWalletWrap {
  // Constants for wallet file extension and path
  static final String _walletExtension = ".wallet";
  static final String _walletDirectory = "wallets";

  // Variables for wallet name and password
  late final String _walletName;
  late final String? _password;
  late bool _isDefault = false;

  late final String? _hash;

  // Seed and a list to store generated seed words before wallet initialization
  String? _seed;
  late List<String> _generatedWordsPreInitWallet = [];

  // List to store wallet objects
  final List<TkmWalletAddress> _addresses = [];

  // Constructor with wallet name and password
  TkmWalletWrap(this._walletName, this._password);
  TkmWalletWrap.restoreWithWords(
      this._walletName, this._password, this._generatedWordsPreInitWallet);

  // Constructor that accepts seed and pre-existing wallet objects
  TkmWalletWrap.withNameSeedAndAddresses(this._walletName, this._seed,
      List<TkmWalletAddress> addresses, this._isDefault) {
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

  /// Wallet seed (available after [initializeWallet]); used for chat key derivation.
  String? get walletSeed => _seed;

  String get walletPath {
    return _walletDirectory;
  }

  String? get hash {
    return _hash;
  }

  bool get isDefault {
    return _isDefault;
  }

  set isDefault(bool isDefault) {
    _isDefault = isDefault;
  }

  // Getter for wallets that are visible
  List<TkmWalletAddress> get visibleAddresses {
    return _addresses.where((wallet) => wallet.visible).toList();
  }

  List<TkmWalletAddress> get chatEligibleAddresses {
    return _addresses.where((a) => a.eligibleForChat).toList();
  }

  List<TkmWalletAddress> get blockchainEligibleAddresses {
    return _addresses.where((a) => a.eligibleForBlockchain).toList();
  }

  // Getter for all wallets
  List<TkmWalletAddress> get addresses {
    return _addresses;
  }

  /// Prefix for encrypted wallet backup files on disk and in the cloud.
  static const String walletBackupFilePrefix = 'tkm_wallet_';

  /// Builds a safe on-disk backup base name: `tkm_wallet_<address>_<epochMs>`.
  static String buildBackupBaseName(String address) {
    final safeAddress = address
        .replaceAll(RegExp(r'[./\\:]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'_$'), '');
    return '${walletBackupFilePrefix}${safeAddress}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Human-readable label for a backup file name or path.
  static String formatBackupDisplayName(String fileNameOrPath) {
    var name = path.basename(fileNameOrPath);
    if (name.toLowerCase().endsWith('.wallet')) {
      name = name.substring(0, name.length - '.wallet'.length);
    }
    if (name.startsWith(walletBackupFilePrefix)) {
      name = name.substring(walletBackupFilePrefix.length);
    }
    return name;
  }

  /// Sanitizes a user-chosen backup label into a safe `.wallet` file name.
  static String sanitizeFriendlyBackupFileName(String input) {
    var name = input.trim();
    if (name.isEmpty) {
      throw ArgumentError('Backup name cannot be empty');
    }
    if (name.toLowerCase().endsWith('.wallet')) {
      name = name.substring(0, name.length - '.wallet'.length);
    }
    name = name
        .replaceAll(RegExp(r'[./\\:]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (name.isEmpty) {
      throw ArgumentError('Backup name cannot be empty');
    }
    return '$name.wallet';
  }

  /// Normalizes a Takamaka address for comparison with backup file name segments.
  static String normalizeAddressForBackupMatch(String address) {
    return address
        .replaceAll(RegExp(r'[./\\:]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'_$'), '');
  }

  /// Extracts the wallet address embedded in an auto-generated backup file name.
  ///
  /// Returns null for friendly renames that no longer follow
  /// `tkm_wallet_<address>_<epochMs>.wallet`.
  static String? extractBackedUpAddress(String fileNameOrPath) {
    var baseName = path.basename(fileNameOrPath);
    if (!baseName.toLowerCase().endsWith('.wallet')) {
      return null;
    }
    if (!baseName.startsWith(walletBackupFilePrefix)) {
      return null;
    }

    var stem = baseName.substring(0, baseName.length - '.wallet'.length);
    stem = stem.substring(walletBackupFilePrefix.length);
    final lastUnderscore = stem.lastIndexOf('_');
    if (lastUnderscore <= 0) {
      return null;
    }

    final epochPart = stem.substring(lastUnderscore + 1);
    if (int.tryParse(epochPart) == null) {
      return null;
    }

    return normalizeAddressForBackupMatch(stem.substring(0, lastUnderscore));
  }

  /// Whether [liveAddress] matches the address encoded in a backup file name.
  static bool backupAddressMatches(
    String safeAddressInFile,
    String liveAddress,
  ) {
    return normalizeAddressForBackupMatch(safeAddressInFile) ==
        normalizeAddressForBackupMatch(liveAddress);
  }

  /// Writes the encrypted wallet backup file and returns its absolute path.
  Future<File> writeEncryptedKeyFiles({String? backupBaseName}) async {
    final fileBaseName = backupBaseName ?? walletName;
    final concat = _generatedWordsPreInitWallet.join(' ');
    final kb = KeyBean('0.1', 'POWSEED', 'Ed25519BC', _seed!, concat);

    // Creates wallets/<walletName>/ side files (words_enc, seed_enc).
    final ekb = CryptoMisc.encryptWallet(
      kb,
      _walletDirectory,
      _walletName,
      _password!,
    );

    final documentsDir = await getApplicationDocumentsDirectory();
    final outputFile = File(
      path.join(
        documentsDir.path,
        _walletDirectory,
        '$fileBaseName$_walletExtension',
      ),
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(jsonEncode(ekb.toJson()));
    return outputFile;
  }

  /// Returns the encrypted wallet backup file after ensuring it exists on disk.
  ///
  /// [backupBaseName] overrides the on-disk file name (without extension).
  /// The logical [walletName] is still used for encryption metadata.
  Future<File> getFile({String? backupBaseName}) async {
    final file = await writeEncryptedKeyFiles(backupBaseName: backupBaseName);
    if (!await file.exists()) {
      throw FileSystemException(
        'Wallet backup file missing after write',
        file.path,
      );
    }
    return file;
  }

  static Future<TkmWalletWrap> restoreFromKeyWords(
      {required List<String> wordList,
      required String walletName,
      required String password}) async {
    var walletWrap =
        TkmWalletWrap.restoreWithWords(walletName, password, wordList);
    await walletWrap.initializeWallet();
    return walletWrap;
  }

  /// Valid mnemonic word count (Takamaka uses 25 words).
  static const List<int> _validMnemonicLengths = [25];

  static Future<TkmWalletWrap> restoreWalletFromFile(
      {required File walletFile,
      required String walletName,
      required String password}) async {
    final String rawContent =
        await FileSystemUtils.readFile(walletFile.path);
    final String trimmed = rawContent.trim();

    final List<String> wordList;
    if (trimmed.startsWith('{')) {
      // Encrypted wallet file (EncKeyBean JSON)
      final String decriptedString =
          CryptoMisc.descryptWallet(rawContent, password);
      final dynamic a = jsonDecode(decriptedString);
      final KeyBean kb = KeyBean.fromJson(a);
      wordList = kb.words.split(" ");
    } else {
      // Plain mnemonic file (e.g. words_walet_*.txt: comma or space separated)
      final List<String> parsedWords = trimmed
          .split(RegExp(r'[\s,]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parsedWords.isEmpty ||
          !_validMnemonicLengths.contains(parsedWords.length)) {
        throw FormatException(
          'Formato file non riconosciuto: usa un file .wallet o un file con '
          'le 25 parole di recupero.',
        );
      }
      wordList = parsedWords;
    }

    return TkmWalletWrap.restoreFromKeyWords(
      walletName: walletName,
      password: password,
      wordList: wordList,
    );
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

    if (_generatedWordsPreInitWallet.isNotEmpty &&
        (_seed == null || _seed!.isEmpty)) {
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
        throw InvalidIndexException(
            "Index 0 is not allowed for remove address wallet.");
      }

      bool isIndexAlreadyUsed =
          _addresses.any((ele) => ele.index == address.index);
      if (isIndexAlreadyUsed == false) {
        throw DuplicateIndexException(
            "Index ${address.index} is not already used by wallet.");
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
        throw InvalidIndexException(
            "Index 0 is not allowed for creating a wallet.");
      }

      // Check if the given index is already used by another wallet
      bool isIndexAlreadyUsed =
          _addresses.any((wallet) => wallet.index == index);

      // If the index is already used, throw a duplicate index exception
      if (isIndexAlreadyUsed) {
        throw DuplicateIndexException(
            "Index $index is already used by wallet.");
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
    List<Map<String, dynamic>> jsonList =
        _addresses.map((wallet) => wallet.toJson()).toList();
    return {
      'isDefault': _isDefault,
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
      json['isDefault'] ?? false,
    );
  }
}
