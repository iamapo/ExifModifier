import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoService extends ChangeNotifier {
  List<AssetEntity> _photosWithoutLocation = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  List<AssetEntity> get photosWithoutLocation => _photosWithoutLocation;

  PhotoService() {
    // Konstruktor bleibt leer
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    await requestPermissionsAndLoadPhotos();
    _isInitialized = true;
  }

  Future<bool> requestPermissionsAndLoadPhotos() async {
    if (_isLoading) return false;

    _isLoading = true;
    // Verzögern Sie den notifyListeners Aufruf
    Future.microtask(() => notifyListeners());

    try {
      final permitted = await PhotoManager.requestPermissionExtend();
      if (!permitted.isAuth) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
        return false;
      }

      await loadPhotos();
      return true;
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> loadPhotos() async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      Set<AssetEntity> uniquePhotosWithoutLocation = {};

      for (var album in albums) {
        final List<AssetEntity> photos = await album.getAssetListPaged(page: 0, size: 50);
        for (var photo in photos) {
          if (await _photoHasNoLocation(photo) &&
              !_isPhotoAlreadyInList(photo, uniquePhotosWithoutLocation)) {
            uniquePhotosWithoutLocation.add(photo);
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
    final latitude = _normalizeCoordinate(await photo.latitude);
    final longitude = _normalizeCoordinate(await photo.longitude);
    return latitude == null || longitude == null;
  }

  double? _normalizeCoordinate(double? coordinate) {
    return coordinate == 0.0 ? null : coordinate;
  }

  bool _isPhotoAlreadyInList(AssetEntity photo, Set<AssetEntity> photoList) {
    return photoList.any((existingPhoto) =>
    existingPhoto.id == photo.id ||
        (existingPhoto.title == photo.title &&
            existingPhoto.createDateTime == photo.createDateTime));
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