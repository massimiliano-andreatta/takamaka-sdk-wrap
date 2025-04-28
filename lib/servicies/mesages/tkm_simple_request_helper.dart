import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart'; // Per la crittografia e firma
import 'package:logger/logger.dart';
import 'package:takamaka_sdk_wrap/models/messages/tkm_message_address.dart';

// Utilizzo di una libreria di logging
var logger = Logger();

// Definizioni per la validazione degli indirizzi
const String ADDRESS_CHECK_ED25519_STRING = r"^[a-zA-Z0-9-_.]{44}$";
const String ADDRESS_CHECK_QTESLA_STRING = r"^[a-zA-Z0-9-_.]{19840}$";
const String ADDRESS_CHECK_COMPACT_STRING = r"^[a-zA-Z0-9-_.]{64}$";

// Funzione per validare gli indirizzi
bool validateAddress(String address, String addressType) {
  RegExp regex;
  switch (addressType) {
    case 'ed25519':
      regex = RegExp(ADDRESS_CHECK_ED25519_STRING);
      break;
    case 'qtesla':
      regex = RegExp(ADDRESS_CHECK_QTESLA_STRING);
      break;
    case 'compact':
      regex = RegExp(ADDRESS_CHECK_COMPACT_STRING);
      break;
    default:
      throw Exception("Tipo di indirizzo non riconosciuto");
  }
  return regex.hasMatch(address);
}

// Funzione per ottenere l'indirizzo
Future<TkmMessageAddress> getAddress(String address) async {
  try {
    CompactAddressBean compactAddress = TkmAddressUtils.toCompactAddress(address);
    // Esegui la logica di validazione dell'indirizzo
    if (validateAddress(address, 'ed25519')) {
      return "Tipo: ed25519, Indirizzo: $address";
    } else if (validateAddress(address, 'qtesla')) {
      return "Tipo: qtesla, Indirizzo: $address";
    } else if (validateAddress(address, 'compact')) {
      return "Tipo: compatto, Indirizzo: $address";
    } else {
      throw Exception("Indirizzo non riconosciuto: $address");
    }
  } catch (e) {
    throw Exception("Errore nell'elaborazione dell'indirizzo: $e");
  }
}

// Funzione per ottenere il JSON in formato prettificato
String getRequestJsonPretty(Map<String, dynamic> baseBean) {
  var encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(baseBean);
}

// Funzione per ottenere il JSON in formato compatto
String getRequestJsonCompact(Map<String, dynamic> baseBean) {
  var encoder = JsonEncoder();
  return encoder.convert(baseBean);
}

// Funzione per ottenere JSON canonico
String getCanonicalJson(Map<String, dynamic> contentBean) {
  var encoder = JsonEncoder();
  String jsonString = encoder.convert(contentBean);
  // Potresti voler aggiungere altre trasformazioni per ottenere un JSON "canonico"
  return jsonString;
}

// Funzione per firmare e criptare un messaggio
Future<String> signEncryptMessage(Map<String, dynamic> baseBean, String password, String scope) async {
  // Crittografia e firma, qui potresti usare pointycastle per implementare la logica di firma
  var privateKey = await getPrivateKey(); // Metodo per ottenere la chiave privata
  var signer = Signer(); // Usando pointycastle per firma

  // Crittografia del messaggio
  var encryptedMessage = encryptMessage(baseBean, password, scope);
  var signature = await signer.signMessage(encryptedMessage, privateKey);

  // Aggiungi la firma al messaggio
  baseBean['signature'] = signature;
  baseBean['encryptedMessageAction'] = encryptedMessage;

  return signature;
}

// Funzione per criptare il messaggio
String encryptMessage(Map<String, dynamic> baseBean, String password, String scope) {
  // Implementa la logica per criptare il messaggio
  return jsonEncode(baseBean); // Placeholder
}

// Funzione di decriptazione
Future<Map<String, dynamic>> decryptMessage(Map<String, dynamic> baseBean, String password, String scope) async {
  // Decodifica del messaggio cifrato
  var encryptedMessage = baseBean['encryptedMessageAction'];
  var decryptedMessage = decryptMessageWithPassword(encryptedMessage, password, scope);

  // Converti il JSON decriptato in un map
  return jsonDecode(decryptedMessage);
}

String decryptMessageWithPassword(String encryptedMessage, String password, String scope) {
  // Implementa la logica di decriptazione qui
  return encryptedMessage; // Placeholder
}

class Signer {
  // Classe di esempio per la gestione della firma
  Future<String> signMessage(String message, String privateKey) async {
    // Logica di firma usando una libreria come pointycastle
    return "signed_message"; // Placeholder
  }
}

Future<String> getPrivateKey() async {
  // Metodo per ottenere la chiave privata dal wallet
  return "private_key"; // Placeholder
}
