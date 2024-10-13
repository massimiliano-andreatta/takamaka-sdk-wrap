import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_wrap.dart';

class TkmWalletShared {
  // Saves a wallet object to shared preferences
  static Future<void> saveWallet(TkmWalletWrap wallet) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current list of wallets from shared preferences, or initialize an empty list if none exists
    List<String>? walletJsonList = prefs.getStringList('wallets');
    walletJsonList ??= [];

    // Deserialize each wallet in the list to convert them back into TkmWalletWrap objects
    List<TkmWalletWrap> wallets = await Future.wait(
      walletJsonList.map((walletJson) async => TkmWalletWrap.fromJson(jsonDecode(walletJson))).toList(),
    );

    // Check if the wallet with the same name already exists
    int existingWalletIndex = wallets.indexWhere((w) => w.walletName == wallet.walletName);

    if (existingWalletIndex != -1) {
      // If the wallet exists, replace it with the new one
      wallets[existingWalletIndex] = wallet;
    } else {
      // If the wallet doesn't exist, add it to the list
      wallets.add(wallet);
    }

    // Serialize the wallet objects back into JSON strings
    List<String> updatedWalletJsonList = wallets.map((w) => jsonEncode(w.toJson())).toList();

    // Save the updated list of wallets to shared preferences
    await prefs.setStringList('wallets', updatedWalletJsonList);
  }


  static Future<List<TkmWalletWrap>> getWallets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get the list of wallet JSON strings from shared preferences
    List<String>? walletJsonList = prefs.getStringList('wallets');

    // If no wallets are found, return an empty list
    if (walletJsonList == null) {
      return [];
    }

    // Deserialize each wallet from JSON and return the list of TkmWalletWrap objects
    List<TkmWalletWrap> wallets = await Future.wait(
      walletJsonList.map((walletJson) async => TkmWalletWrap.fromJson(jsonDecode(walletJson))).toList(),
    );

    return wallets;
  }


  // Deletes a wallet from shared preferences by its name
  static Future<void> deleteWallet(String walletName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the current list of wallets from shared preferences, or initialize an empty list if none exists
    List<String>? walletJsonList = prefs.getStringList('wallets');
    walletJsonList ??= [];

    // Deserialize each wallet JSON string to get the TkmWalletWrap objects
    List<TkmWalletWrap> wallets = await Future.wait(
      walletJsonList.map((walletJson) async => TkmWalletWrap.fromJson(jsonDecode(walletJson))).toList(),
    );

    // Remove the wallet from the list where the name matches the provided wallet name
    wallets.removeWhere((wallet) => wallet.walletName == walletName);

    // Serialize the updated list of wallet objects back into JSON strings
    List<String> updatedWalletJsonList = wallets.map((w) => jsonEncode(w.toJson())).toList();

    // Save the updated list to shared preferences
    await prefs.setStringList('wallets', updatedWalletJsonList);
  }
}
