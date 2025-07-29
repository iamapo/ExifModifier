import 'package:MapMyShot/services/similarity_service.dart';
import 'package:flutter/material.dart';
import '../services/exif_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class PhotoDetailsViewModel with ChangeNotifier {
  final AssetEntity photo;
  final ExifService exifService;
  final SimilarityService similarityService;
  Map<AssetEntity, String> similarLocations = {};
  List<AssetEntity> similar = [];
  String timeRange = '1 hour';
  bool loadingSimilar = false;

  PhotoDetailsViewModel({required this.photo, required this.exifService, required this.similarityService});

  Future<void> init() async {
    await loadSimilar();
  }

  Duration _dur(String t) {
    switch (t) {
      case '4 hours': return Duration(hours: 4);
      case '12 hours': return Duration(hours: 12);
      default: return Duration(hours: 1);
    }
  }

  Future<void> loadSimilar() async {
    loadingSimilar = true;
    notifyListeners();
    final all = await similarityService.findByTimeAndGps(photo, _dur(timeRange));
    similar = all;
    similarLocations = {};
    for (var e in all) {
      similarLocations[e] = await exifService.getLocationName(e);
    }
    loadingSimilar = false;
    notifyListeners();
  }

  static const MethodChannel _channel = MethodChannel('io.flutter.flutter.app/photo_location');

  Future<bool> applyLocation(AssetEntity src) async {
    final isAvailable = await src.isLocallyAvailable();
    if (!isAvailable) {
      final file = await src.originFile;
      if (file == null) {
        debugPrint('Foto ist nicht lokal verfügbar und konnte nicht heruntergeladen werden.');
        return false;
      }
    }

    final lat = await exifService.getLatitude(src);
    final lon = await exifService.getLongitude(src);

    if (lat == null || lon == null) {
      debugPrint('EXIF-Daten konnten nicht gelesen werden.');
      return false;
    }

    try {
      final ok = await _channel.invokeMethod('updatePhotoLocation', {
        'localId': src.id,
        'latitude': lat,
        'longitude': lon,
      });
      return ok == true;
    } catch (e) {
      debugPrint('Fehler beim Schreiben der Location: $e');
      return false;
    }
  }
}