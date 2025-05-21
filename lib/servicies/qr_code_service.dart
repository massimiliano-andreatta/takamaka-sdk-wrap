import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/actions/pay_qr_data.dart'; // Aggiornato import

class QrCodeService {
  /// Serializza [PayQrData] in una stringa JSON compatta.
  static String generatePayQrJson(PayQrData data) {
    return data.toJsonString(); // Utilizza il metodo toJsonString di PayQrData
  }

  /// Genera un widget [QrImageView] per visualizzare un QRCode basato su [PayQrData].
  ///
  /// [data]: L'oggetto [PayQrData] da codificare nel QRCode.
  /// [size]: La dimensione del QRCode (larghezza e altezza). Default 200.0.
  /// [qrColor]: Il colore dei moduli del QRCode. Default Colors.black.
  /// [backgroundColor]: Il colore di sfondo del QRCode. Default Colors.white.
  /// [gapless]: Se true, non ci saranno spazi tra i moduli. Default true.
  /// [version]: La versione del QRCode. Default QrVersions.auto.
  /// [errorCorrectionLevel]: Il livello di correzione degli errori. Default QrErrorCorrectLevel.L.
  static Widget generatePayQrWidget(
    PayQrData data, {
    // Tipo di dato aggiornato a PayQrData
    double size = 200.0,
    Color qrColor = Colors.black,
    Color backgroundColor = Colors.white,
    bool gapless = true,
    int version = QrVersions.auto,
    int errorCorrectionLevel = QrErrorCorrectLevel.L,
  }) {
    final String jsonData = generatePayQrJson(data);
    return QrImageView(
      data: jsonData,
      version: version,
      size: size,
      gapless: gapless,
      backgroundColor: backgroundColor,
      // ignore: deprecated_member_use
      foregroundColor: qrColor,
      errorCorrectionLevel: errorCorrectionLevel,
      // eyeStyle: QrEyeStyle( // Esempio di personalizzazione più moderna
      //   eyeShape: QrEyeShape.square,
      //   color: qrColor,
      // ),
      // dataModuleStyle: QrDataModuleStyle( // Esempio di personalizzazione più moderna
      //   dataModuleShape: QrDataModuleShape.square,
      //   color: qrColor,
      // ),
    );
  }

  /// Deserializza una stringa JSON [qrJsonData] (ottenuta da uno scanner QR)
  /// in un oggetto [PayQrData].
  ///
  /// Restituisce [PayQrData] se il parsing ha successo, altrimenti `null`.
  static PayQrData? parsePayQrJson(String qrJsonData) {
    // Tipo di ritorno aggiornato
    try {
      // Utilizza il factory fromJsonString di PayQrData
      return PayQrData.fromJsonString(qrJsonData);
    } on FormatException catch (e) {
      debugPrint(
          "Errore di formato durante il parsing del JSON del QR Code: $e");
      return null;
    } catch (e) {
      debugPrint(
          "Errore imprevisto durante il parsing del JSON del QR Code: $e");
      return null;
    }
  }
}
