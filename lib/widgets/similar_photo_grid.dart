import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SimilarPhotosGrid extends StatelessWidget {
  final List<AssetEntity> photos;
  final Map<AssetEntity, String> locationNames;
  final Function(AssetEntity) onPhotoTap;

  const SimilarPhotosGrid({
    super.key,
    required this.photos,
    required this.locationNames,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noSimilarPictures,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () => onPhotoTap(photo),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AssetEntityImage(
                    photo,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    locationNames[photo] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}