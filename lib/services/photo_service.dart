import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '/utilities/exif_utils.dart';


class PhotoService extends ChangeNotifier {
  List<AssetEntity> _photosWithoutLocation = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  List<AssetEntity> get photosWithoutLocation => _photosWithoutLocation;

  PhotoService();

  void clearCache() {
    _photosWithoutLocation.clear();
    notifyListeners(); // Notify listeners about the change
  }

  void removePhotoFromList(AssetEntity photo) {
    photosWithoutLocation.removeWhere((element) => element.id == photo.id);
    notifyListeners(); // Aktualisiert die UI
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    await requestPermissionsAndLoadPhotos();
    _isInitialized = true;
  }

  Future<bool> requestPermissionsAndLoadPhotos({String? timeRange}) async {
    if (_isLoading) return false;

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final PermissionState permissionState = await PhotoManager.requestPermissionExtend();

      print("Berechtigungsstatus: $permissionState");

      if (permissionState == PermissionState.limited) {
        // Optional: Benutzer auf begrenzten Zugriff hinweisen
        print("Begrenzter Zugriff gewährt");
      } else if (permissionState != PermissionState.authorized) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
        return false;
      }

      await loadPhotos();
      return true;
    } catch (e) {
      print('Fehler beim Anfordern von Berechtigungen: $e');
      return false;
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> loadPhotos({String? timeRange}) async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          containsPathModified: false, // Nur lokal gespeicherte Fotos
        ),
      );

      Set<AssetEntity> uniquePhotosWithoutLocation = {};

      for (var album in albums) {
        final List<AssetEntity> photos =
        await album.getAssetListPaged(page: 0, size: 50);
        for (var photo in photos) {
          if (await _photoHasNoLocation(photo) &&
              !_isPhotoAlreadyInList(photo, uniquePhotosWithoutLocation)) {
            // Apply time range filter if specified
            if (timeRange != null && timeRange != 'All') {
              final now = DateTime.now();
              final filterStartTime =
              now.subtract(getTimeRangeDuration(timeRange));
              if (photo.createDateTime.isAfter(filterStartTime)) {
                uniquePhotosWithoutLocation.add(photo);
              }
            } else {
              // No time range filter, add all photos
              uniquePhotosWithoutLocation.add(photo);
            }
          }
        }
      }

      _photosWithoutLocation = uniquePhotosWithoutLocation.toList()
        ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    } catch (e) {
      print('Fehler beim Laden der Fotos: $e');
      _photosWithoutLocation = [];
    }
  }

  Future<bool> _photoHasNoLocation(AssetEntity photo) async {
    final file = await photo.file;
    if (file != null) {
      final exifData = await readExifFromBytes(await file.readAsBytes());
      //exifData.forEach((k, v) {
      //  print("$k: $v \n");
      //});
      final latitudeRef = exifData['GPS GPSLatitudeRef']?.printable;
      final latitude = exifData['GPS GPSLatitude']?.printable;
      final longitudeRef = exifData['GPS GPSLongitudeRef']?.printable;
      final longitude = exifData['GPS GPSLongitude']?.printable;

      // Check if latitude and longitude are present and not 0
      if (latitude != null &&
          longitude != null &&
          latitude != '0' &&
          longitude != '0' &&
          latitudeRef != null &&
          longitudeRef != null) {
        //print('Photo ID: ${photo.id} latitudeRef: ${latitudeRef} latitude: ${latitude} longitudeRef: ${longitudeRef} longitude: ${longitude}');
        return false; // Photo has location data
      }
    }
    return true; // Photo has no location data or EXIF data is inaccessible
  }

  double? _normalizeCoordinate(double? coordinate) {
    return coordinate == 0.0 ? null : coordinate;
  }

  bool _isPhotoAlreadyInList(AssetEntity photo, Set<AssetEntity> photoList) {
    return photoList.any((existingPhoto) => existingPhoto.id == photo.id);
  }

  Future<void> deletePhoto(AssetEntity photo) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([photo.id]);
      if (result.isNotEmpty) {
        _photosWithoutLocation.remove(photo);
        notifyListeners();
      } else {
        print('Fehler beim Löschen des Fotos');
      }
    } catch (e) {
      print('Fehler beim Löschen des Fotos: $e');
    }
  }

  Future<void> removePhoto(AssetEntity photo) async {
    _photosWithoutLocation.removeWhere((p) => p.id == photo.id);
    notifyListeners();
  }
}