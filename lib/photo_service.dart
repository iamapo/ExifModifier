import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoService extends ChangeNotifier {
  List<AssetEntity> _photosWithoutLocation = [];
  bool _isLoading = false;

  List<AssetEntity> get photosWithoutLocation => _photosWithoutLocation;
  bool get isLoading => _isLoading;

  Future<bool> requestPermissionsAndLoadPhotos() async {
    final PermissionState result = await PhotoManager.requestPermissionExtend();
    if (result.isAuth) {
      await loadPhotos();
    }
    return result.isAuth;
  }

  Future<void> loadPhotos() async {
    _isLoading = true;
    notifyListeners();

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
    _isLoading = false;
    notifyListeners();
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
    final result = await PhotoManager.editor.deleteWithIds([photo.id]);
    if (result.isNotEmpty) {
      _photosWithoutLocation.remove(photo);
      notifyListeners();
    }
  }
}