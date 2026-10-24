String formatMinorCurrency(int amountMinor) {
  final rupees = amountMinor ~/ 100;
  final paise = amountMinor % 100;
  if (paise == 0) return '₹$rupees';
  return '₹$rupees.${paise.toString().padLeft(2, '0')}';
}
