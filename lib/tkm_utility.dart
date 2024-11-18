import 'dart:convert';

class TkmUtility {

  static bool isValidBlockchainAddress(String address) {
    // Check the length
    if (address.length != 44) {
      return false;
    }

    // Check Base64URL encoding
    try {
      // Decode the string using Base64URL
      final decoded = base64Url.decode(address);
      // Re-encode the decoded data back to Base64URL
      final reEncoded = base64Url.encode(decoded);

      // Verify that the original string matches the re-encoded string
      if (address != reEncoded) {
        return false;
      }
    } catch (e) {
      return false; // If decoding fails, it's not valid Base64URL
    }

    return true;
  }

}