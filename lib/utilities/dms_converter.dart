

double? convertDmsToDecimal(String? dms) {
  if (dms == null) return null;
  final parts = dms.replaceAll(RegExp(r'[\[\]]'), '').split(', ').map((p) {
    if (p.contains('/')) {
      final f = p.split('/');
      return double.parse(f[0]) / double.parse(f[1]);
    }
    return double.parse(p);
  }).toList();
  if (parts.length != 3) return null;
  return parts[0] + parts[1]/60 + parts[2]/3600;
}