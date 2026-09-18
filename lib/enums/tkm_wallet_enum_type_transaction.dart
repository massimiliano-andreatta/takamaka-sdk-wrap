library takamaka_sdk_wrap;

enum TkmWalletEnumTypeTransaction {
  all('ALL'),
  pay('PAY'),
  blob('BLOB'),
  stake('STAKE'),
  stakeUndo('STAKE_UNDO');

  final String value;

  const TkmWalletEnumTypeTransaction(this.value);
}
