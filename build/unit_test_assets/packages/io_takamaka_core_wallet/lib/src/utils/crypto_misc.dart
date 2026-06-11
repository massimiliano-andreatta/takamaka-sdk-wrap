import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:encrypt/encrypt.dart';
import 'package:hex/hex.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:io_takamaka_core_wallet/src/model/enc_key_bean.dart';
import 'package:io_takamaka_core_wallet/src/model/key_bean.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:sha3/sha3.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// these methods use several external packages such as hex and crypto.
/// The hex package provides functions for encoding and decoding hexadecimal strings,
/// while the crypto package provides cryptographic functions for hashing and key derivation.
/// These packages provide basic cryptographic capabilities for Flutter applications.
class CryptoMisc {
  static const int dictionaryAllLength = 2048;
  static const int wordsLength = 25;
  static const String walletKeyChain = "__WKCH__";

  /// This method takes a string input, converts it to bytes using UTF-8 encoding, computes the SHA3-256 hash of the bytes, and returns the hash value as a hexadecimal string.
  static String hash256ToHex(String input) {
    List<int> bytes = utf8.encode(input);
    String hexVersion = hex.encode(bytes);
    var k = SHA3(256, SHA3_PADDING, 256);
    k.update(bytes);
    var hash = k.digest();
    hexVersion = HEX.encode(hash);
    return hexVersion;
  }

  /// This method takes a string input, a salt string salt, an integer iterations for the number of iterations of the PBKDF2 algorithm, and an integer bitLengthKey for the bit length of the derived key. It then uses the PBKDF2 algorithm with HMAC-SHA512 as the MAC algorithm to derive a key from the input and salt strings. The derived key is returned as a list of integers.
  static Future<List<int>> pwHash(
      String input, String salt, int iterations, int bitLengthKey) async {
    final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha512(),
        iterations: iterations,
        bits: bitLengthKey);
    final secretKey = SecretKey(utf8.encode(input));

    // A random salt
    final nonce = utf8.encode(salt);

    // Calculate a hash that can be stored in the database
    final newSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: nonce,
    );
    final newSecretKeyBytes = await newSecretKey.extractBytes();
    return newSecretKeyBytes;
  }

  static Future<bool> verifySign(TransactionBean tb) async {
    final algorithm = DartEd25519(sha512: Sha512());
    var message = (tb.message! + tb.randomSeed! + tb.walletCypher!);

    Signature sigExt = await generateSignature(tb.signature!, tb.publicKey!);

    return await algorithm.verifyString(
      message,
      signature: sigExt,
    );
  }
///The method is a static asynchronous method that performs signing and verification of a message using the Ed25519 digital signature algorithm
///The method takes a SimpleKeyPair object (keyPair) and a String (message) as input.
///An instance of the DartEd25519 class is created, configured with the Sha512 hashing algorithm for signature generation and verification.
///The signString method of the DartEd25519 instance is used to sign the message using the keyPair. This produces an unsignedSignature object.
///The verifyString method is then used to verify the signature by passing the message and the unsignedSignature to it. The result is stored in the isSignatureCorrect variable.
///If the signature is verified successfully (isSignatureCorrect is true), the following steps are performed:
///The signature bytes are converted to a base64 representation using the base64.encode function.
///The resulting base64 signature is then converted to a URL-safe base64 representation using the StringUtilities.convertFromBase64ToBase64UrlSafe method.
///The URL-safe base64 signature is returned as the result of the method.
///If the signature verification fails (isSignatureCorrect is false), an error is thrown using throw Error().
  static Future<String> signAndVerify(SimpleKeyPair keyPair, String message) async {
    final algorithm = DartEd25519(sha512: Sha512());

    // Signing the message
    Signature unsignedSignature = await algorithm.signString(
      message,
      keyPair: keyPair,
    );

    // Verifying the signature
    final isSignatureCorrect = await algorithm.verifyString(
      message,
      signature: unsignedSignature,
    );

    if (isSignatureCorrect) {
      // Converting the signature bytes to base64 representation
      var base64Sig = base64.encode(unsignedSignature.bytes);

      // Converting the base64 signature to a URL-safe base64 representation
      var base64UrlSafeSig = StringUtilities.convertFromBase64ToBase64UrlSafe(base64Sig);

      return base64UrlSafeSig;
    } else {
      // If the signature verification fails, an error is thrown
      throw Error();
    }
  }

  /// This method generates a sequence of cryptographically secure random bytes
  /// using the Random.secure() method from the dart:math library.
  /// It takes an integer parameter length that specifies the number of bytes
  /// to generate and returns a Uint8List object containing the generated bytes.
  static Uint8List _generateRandomBytes(int length) {
    //final secureRandom = encrypt.SecureRandom(length);
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return Uint8List.fromList(values);
  }

  /// This method generates a PBKDF2 key from the given password
  /// and salt using the PBKDF2KeyDerivator class from the pointycastle library.
  /// It takes a String parameter password that specifies the password to use,
  /// and a Uint8List parameter salt that specifies the salt to use.
  /// It returns a Uint8List object containing the generated key.
  static Uint8List _generatePbkdf2Key(String password, Uint8List salt) {
    final pbkdf2KeyDerivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 64));
    final pbkdf2Parameters = Pbkdf2Parameters(
        salt, 1, 32); // salt, iterations, key length
    pbkdf2KeyDerivator.init(pbkdf2Parameters);
    final key = pbkdf2KeyDerivator.process(
        Uint8List.fromList(utf8.encode(password)));

    return key;
  }

  static EncKeyBean encryptWallet(KeyBean kb, String walletDirectory, String walletName, String password) {
    String jsonWallet = kb.toJson().toString();
    final saltBytes = Uint8List.fromList(utf8.encode("TakamakaWallet"));

    // Derive the key from the password and salt using PBKDF2
    final key = _generatePbkdf2Key(password, saltBytes);

    // Generate a random IV (Initialization Vector)
    final iv = _generateRandomBytes(16);
    String base64StringKeyBack = base64Encode(iv);

    // Create an AES block cipher with CBC mode of operation
    final encrypter =
        Encrypter(AES(encrypt.Key(Uint8List.fromList(key)), mode: AESMode.cbc));
    final encryptedSeed = encrypter.encrypt(kb.seed, iv: IV(Uint8List.fromList(iv)));
    final encryptedWords = encrypter.encrypt(kb.words, iv: IV(Uint8List.fromList(iv)));
    // Encrypt the plaintext using AES-256 with the derived key and IV
    final encrypted =
        encrypter.encrypt(jsonWallet, iv: IV(Uint8List.fromList(iv)));

    FileSystemUtils.saveFileInWalletDir(
        walletDirectory, walletName, 'words_enc', encryptedWords.base64);
    FileSystemUtils.saveFileInWalletDir(
        walletDirectory, walletName, 'seed_enc', encryptedSeed.base64);

    EncKeyBean ekb = EncKeyBean("0.1", "AES", [
      base64StringKeyBack,
      encrypted.base64
    ]);

    return ekb;

  }

  /// This method decrypts an encrypted string using the AES-256 algorithm
  /// with the given password and initialization vector (IV).
  /// It uses the Encrypter class from the encrypt library
  /// to perform the decryption.
  /// The encrypted string is expected to be in JSON format
  /// and contains an initialization vector and a ciphertext.
  /// The method returns the decrypted string in JSON format after converting it
  /// to the correct format using
  /// the StringUtilities.jsonNotEscapedToCorrectFormat method.
  static String descryptWallet(String encriptedWallet, String password){
    dynamic a = jsonDecode(encriptedWallet);

    EncKeyBean ekb = EncKeyBean.fromJson(a);
    final saltBytes = Uint8List.fromList(utf8.encode("TakamakaWallet"));
    final key = _generatePbkdf2Key(password, saltBytes);

    String ivD = ekb.wallet[0];
    final iv = base64Decode(ivD);

    // Create an AES block cipher with CBC mode of operation
    final encrypter = Encrypter(
        AES(encrypt.Key(Uint8List.fromList(key)), mode: AESMode.cbc));

    final ciphertext = Encrypted.fromBase64(ekb.wallet[1]);

    // Decifra il ciphertext utilizzando AES-256 con la chiave e l'IV
    String decryptedWallet = encrypter.decrypt(
        ciphertext, iv: IV(Uint8List.fromList(iv)));

    String escapedJson = StringUtilities.jsonNotEscapedToCorrectFormat(decryptedWallet);

    return escapedJson;
  }

  static Future<Signature> generateSignature(String signature, String publicKey) async {
    String base64key = StringUtilities.convertFromBase64UrlSafeToBase64(publicKey);
    SimplePublicKey s = SimplePublicKey(base64.decode(base64key), type: KeyPairType.ed25519);
    SimpleKeyPair kp = SimpleKeyPairData([], publicKey: s, type: KeyPairType.ed25519);
    Signature sigExt = Signature(StringUtilities.fromB64UrlToBytes(signature), publicKey: await kp.extractPublicKey());
    return sigExt;
  }

}
