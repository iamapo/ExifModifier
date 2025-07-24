import 'package:photo_manager/photo_manager.dart';
import 'exif_service.dart';

class SimilarityService {
  final ExifService exif;

  SimilarityService(this.exif);

  Future<List<AssetEntity>> findByTimeAndGps(
      AssetEntity target,
      Duration threshold,
      ) async {
    final min = target.createDateTime.subtract(threshold);
    final max = target.createDateTime.add(threshold);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      filterOption: FilterOptionGroup(
        createTimeCond: DateTimeCond(min: min, max: max),
      ),
    );
    if (albums.isEmpty) return [];

    final all = await albums.first.getAssetListRange(start: 0, end: 999999);
    final result = <AssetEntity>[];

    for (final image in all) {
      if (image.id == target.id) continue;
      final lat = await exif.getLatitude(image);
      final lon = await exif.getLongitude(image);
      if (lat != null && lon != null) {
        result.add(image);
      }
    }
    return result;
  }
}