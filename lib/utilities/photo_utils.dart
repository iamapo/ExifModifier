import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoUtils {
  // Findet ähnliche Bilder basierend auf einem Zeitfenster
  static Future<List<AssetEntity>> findSimilarImages(
      AssetEntity targetImage,
      Duration timeThreshold,
      ) async {
    try {
      final DateTime minDate = targetImage.createDateTime.subtract(timeThreshold);
      final DateTime maxDate = targetImage.createDateTime.add(timeThreshold);

      // Hol die Alben, die Bilder im Zeitfenster enthalten
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          createTimeCond: DateTimeCond(min: minDate, max: maxDate),
        ),
      );

      if (albums.isEmpty) return [];

      // Lade alle Bilder aus dem ersten Album
      final List<AssetEntity> allImages =
      await albums.first.getAssetListRange(start: 0, end: 999999);

      final targetExifData = await _getExifData(targetImage);
      final targetLatitude = targetExifData?['GPS GPSLatitude']?.printable;
      final targetLongitude = targetExifData?['GPS GPSLongitude']?.printable;

      List<AssetEntity> similarImages = [];
      for (var image in allImages) {
        if (image.id == targetImage.id) continue; // Zielbild selbst überspringen

        final imageExifData = await _getExifData(image);
        final imageLatitude = imageExifData?['GPS GPSLatitude']?.printable;
        final imageLongitude = imageExifData?['GPS GPSLongitude']?.printable;

        // Vergleiche die EXIF-Koordinaten
        if (imageLatitude != null && imageLongitude != null) {
          similarImages.add(image);
        }
      }

      return similarImages;
    } catch (e) {
      print('Fehler in findSimilarImages: $e');
      return [];
    }
  }

  // Ruft EXIF-Daten eines Bildes ab
  static Future<Map<String, IfdTag>?> _getExifData(AssetEntity photo) async {
    try {
      final file = await photo.file;
      if (file == null) return null;

      final Uint8List bytes = await file.readAsBytes();
      return await readExifFromBytes(bytes);
    } catch (e) {
      print('Fehler beim Abrufen der EXIF-Daten: $e');
      return null;
    }
  }

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
