class PhotoUtils {

  // Konvertiert DMS (Grad, Minuten, Sekunden) in Dezimalgrad
  static double? convertDmsToDecimal(String? dmsString) {
    if (dmsString == null) return null;

    try {
      dmsString = dmsString.replaceAll(RegExp(r'[\[\]]'), '');
      final parts = dmsString.split(', ').map((part) {
        if (part.contains('/')) {
          final fractionParts = part.split('/');
          return double.parse(fractionParts[0]) / double.parse(fractionParts[1]);
        }
        return double.parse(part);
      }).toList();

      if (parts.length != 3) return null;

      return parts[0] + (parts[1] / 60) + (parts[2] / 3600);
    } catch (e) {
      print('Fehler beim Konvertieren von DMS zu Dezimal: $e');
      return null;
    }
  }
}
