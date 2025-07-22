import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

/// Hilfsfunktion: gruppiert eine Liste von AssetEntitys nach 'MMMM yyyy' (de_DE)
Map<String, List<AssetEntity>> groupByMonth(List<AssetEntity> photos) {
  final Map<String, List<AssetEntity>> map = {};
  final fmt = DateFormat('MMMM yyyy', 'de_DE');

  for (var asset in photos) {
    final date = asset.createDateTime;
    final key = fmt.format(date);
    map.putIfAbsent(key, () => []).add(asset);
  }
  return map;
}