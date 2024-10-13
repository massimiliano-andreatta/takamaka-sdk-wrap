// Exception thrown when a requested wallet is not found
class WalletNotFoundException implements Exception {
  final String message;
  WalletNotFoundException(this.message);

  @override
  String toString() => 'WalletNotFoundException: $message';
}

// Exception thrown when attempting to add an address with an invalid index
class InvalidIndexException implements Exception {
  final String message;
  InvalidIndexException(this.message);

  @override
  String toString() => 'InvalidIndexException: $message';
}

// Exception thrown when attempting to add an address that already exists
class DuplicateIndexException implements Exception {
  final String message;
  DuplicateIndexException(this.message);

  @override
  String toString() => 'DuplicateIndexException: $message';
}

class WalletAlreadyExistsException implements Exception {
  final String message;
  WalletAlreadyExistsException(this.message);

  @override
  String toString() => "WalletAlreadyExistsException: $message";
}