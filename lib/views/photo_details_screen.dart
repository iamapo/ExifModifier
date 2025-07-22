import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/SimilarityService.dart';
import '../services/exif_service.dart';
import '../view_models/PhotoDetailsViewModel.dart';
import '../widgets/similar_photo_grid.dart';

class PhotoDetailsScreen extends StatelessWidget {
  final AssetEntity photo;
  final VoidCallback onSaved;
  const PhotoDetailsScreen({Key? key, required this.photo, required this.onSaved}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = PhotoDetailsViewModel(photo: photo, exifService: ExifService(), similarityService: SimilarityService(ExifService()));
        vm.init();
        return vm;
      },
      child: Consumer<PhotoDetailsViewModel>(
        builder: (context, vm, __) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.photoDetails),
              actions: [
                DropdownButton<String>(
                  value: vm.timeRange,
                  items: ['1 hour', '4 hours', '12 hours']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    vm.timeRange = v!;
                    vm.loadSimilar();
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                AspectRatio(aspectRatio: 1, child: AssetEntityImage(photo)),
                Expanded(
                  child: vm.loadingSimilar
                      ? Center(child: CircularProgressIndicator())
                      : SimilarPhotosGrid(
                    photos: vm.similar,
                    locationNames: vm.similarLocations,
                    onPhotoTap: (src) async {
                      final ok = await vm.applyLocation(src);
                      if (ok) {
                        onSaved();
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.errorSendingLocation)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
