/// Converts a price string like "299.00" (as sent by the backend's
/// Prisma Decimal, always with 2 decimal places) into integer cents.
/// All cart math is done in integer cents so it's never subject to
/// binary floating-point rounding error - only the final display value
/// is turned back into a decimal string.
int priceStringToCents(String price) {
  final parts = price.trim().split('.');
  final whole = int.tryParse(parts[0]) ?? 0;
  final fractionRaw = parts.length > 1 ? parts[1] : '';
  final fraction = fractionRaw.padRight(2, '0').substring(0, 2);
  final fractionValue = int.tryParse(fraction) ?? 0;
  final sign = price.trim().startsWith('-') ? -1 : 1;
  return sign * (whole.abs() * 100 + fractionValue);
}

/// Formats integer cents back into a plain "299.00"-style string for
/// display, matching how prices already render elsewhere in the app
/// (no currency symbol is assumed anywhere in ScanServe today).
String centsToDisplayString(int cents) {
  final isNegative = cents < 0;
  final absCents = cents.abs();
  final whole = absCents ~/ 100;
  final fraction = (absCents % 100).toString().padLeft(2, '0');
  return '${isNegative ? '-' : ''}$whole.$fraction';
}
