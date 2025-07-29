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

  Future<void> loadPhotos({int maxPerAlbum = 20, int batchSize = 10}) async {
    isLoading = true;
    photos.clear();
    notifyListeners();

    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      final Set<String> seenIds = {};
      final List<AssetEntity> candidates = [];

      for (final album in paths) {
        final list = await album.getAssetListPaged(page: 0, size: maxPerAlbum);
        for (final e in list) {
          if (!seenIds.contains(e.id)) {
            seenIds.add(e.id);
            candidates.add(e);
          }
        }
      }

      for (int i = 0; i < candidates.length; i += batchSize) {
        final batch = candidates.skip(i).take(batchSize).toList();

        final results = await Future.wait(batch.map((asset) async {
          final lat = await exifService.getLatitude(asset);
          final lon = await exifService.getLongitude(asset);
          final hasLocation = lat != null && lon != null;

          return hasLocation ? null : asset;
        }));

        photos.addAll(results.whereType<AssetEntity>());
        photos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        notifyListeners();
      }
    } catch (e, stack) {
      debugPrint('$stack');
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