import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/similarity_service.dart';
import '../services/exif_service.dart';
import '../view_models/PhotoDetailsViewModel.dart';
import '../widgets/similar_photo_grid.dart';

class PhotoDetailsScreen extends StatelessWidget {
  final AssetEntity photo;
  final VoidCallback onSaved;

  const PhotoDetailsScreen({
    super.key,
    required this.photo,
    required this.onSaved,
  });

  static const _mapMyShotOrange = Color(0xFFFFA500);


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotoDetailsViewModel>(
      create: (_) {
        final vm = PhotoDetailsViewModel(
          photo: photo,
          exifService: ExifService(),
          similarityService: SimilarityService(ExifService()),
        );
        vm.init();
        return vm;
      },
      child: Consumer<PhotoDetailsViewModel>(
        builder: (context, vm, __) {
          final loc = AppLocalizations.of(context)!;
          // Liste der Optionen mit Localized-Strings
          final options = <String>[
            loc.timeRange1Hour,
            loc.timeRange4Hours,
            loc.timeRange12Hours,
          ];

          if (!options.contains(vm.timeRange)) {
            vm.timeRange = options[0];    // "1 Stunde"
            vm.loadSimilar();
          }
          // Aktiver Index in der SegmentControl
          final currentIndex = options.indexOf(vm.timeRange);

          return Scaffold(
            appBar: AppBar(
              title: Text(loc.photoDetails),
              elevation: 0,
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                // 1. Großes Foto
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AssetEntityImage(
                      photo,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Datum & Titel
                Text(
                  // formatiere Datum, z.B. "24. April 2024"
                  DateFormat.yMMMMd(loc.localeName).format(photo.createDateTime),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  photo.title ?? loc.photoWithoutTitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),

                // 3. Segmentierter Filter
                Center(
                  child: ToggleButtons(
                    isSelected: List.generate(options.length, (i) => i == currentIndex),
                    onPressed: (i) {
                      vm.timeRange = options[i];
                      vm.loadSimilar();
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Theme.of(context).colorScheme.onPrimary,
                    fillColor: _mapMyShotOrange,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    children: options
                        .map((text) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(text),
                    ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Ähnliche Fotos im 3-Spalten-Raster
                vm.loadingSimilar
                    ? const Center(child: CircularProgressIndicator())
                    : SimilarPhotosGrid(
                  photos: vm.similar,
                  locationNames: vm.similarLocations,
                  onPhotoTap: (src) async {
                    final ok = await vm.applyLocation(src);
                    if (ok) {
                      onSaved();
                      if (context.mounted) Navigator.pop(context);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.errorSendingLocation)),
                      );
                    }
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
