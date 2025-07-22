import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'exif_service.dart';


class PhotoService with ChangeNotifier {
  final ExifService exifService;
  List<AssetEntity> photos = [];
  bool isLoading = false;

  PhotoService({required this.exifService});

  Future<bool> requestPermissions() async {
    final perm = await PhotoManager.requestPermissionExtend();
    return perm == PermissionState.authorized || perm == PermissionState.limited;
  }

  Future<void> loadPhotos({String? timeRange}) async {
    isLoading = true;
    notifyListeners();

    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      final List<AssetEntity> result = [];
      final Set<String> seenIds = {};

      for (final album in paths) {
        final list = await album.getAssetListPaged(page: 0, size: 100);
        for (final e in list) {
          if (seenIds.contains(e.id)) {
            continue;
          }
          seenIds.add(e.id);

          final lat = await exifService.getLatitude(e);
          final lon = await exifService.getLongitude(e);

          if (lat == null || lon == null) {
            result.add(e);
          } else {
          }
        }
      }

      photos = result
        ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void remove(AssetEntity e) {
    photos.removeWhere((f) => f.id == e.id);
    notifyListeners();
  }
}