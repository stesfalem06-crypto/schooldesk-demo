/// Whole nakfa amounts, with thousands separators. 450000.0 becomes "450,000 Nfk".
String nfk(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;
  final whole = number.round();
  final digits = whole.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '${whole < 0 ? '-' : ''}$out Nfk';
}
