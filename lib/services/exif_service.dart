import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import '../utilities//dms_converter.dart';
import 'package:geocoding/geocoding.dart';

class ExifService {
  final Map<String, Map<String, IfdTag>> _cache = {};
  final Map<String, String> _locationCache = {};

  Future<Map<String, IfdTag>?> readExif(AssetEntity e) async {
    if (_cache.containsKey(e.id)) {
      return _cache[e.id];
    }
    final file = await e.originFile;
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    Map<String, IfdTag> exif;
    try {
      exif = await readExifFromBytes(bytes);
    } catch (err, st) {
      return null;
    }
    _cache[e.id] = exif;
    return exif;
  }

  Future<double?> getLatitude(AssetEntity e) async {
    final exif = await readExif(e);
    final raw = exif?['GPS GPSLatitude']?.printable;
    return convertDmsToDecimal(raw);
  }

  Future<double?> getLongitude(AssetEntity e) async {
    final exif = await readExif(e);
    final raw = exif?['GPS GPSLongitude']?.printable;
    return convertDmsToDecimal(raw);
  }

  Future<String> getLocationName(AssetEntity e) async {
    final key = e.id;
    if (_locationCache.containsKey(key)) return _locationCache[key]!;
    final lat = await getLatitude(e);
    final lon = await getLongitude(e);
    if (lat == null || lon == null) return 'Keine Location verfügbar';
    final placemarks = await placemarkFromCoordinates(lat, lon);
    final name = placemarks.isNotEmpty
        ? '${placemarks.first.locality}, ${placemarks.first.country}'
        : 'Location nicht gefunden';
    _locationCache[key] = name;
    return name;
  }
}