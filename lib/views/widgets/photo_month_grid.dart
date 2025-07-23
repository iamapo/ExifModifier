import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class PhotoMonthGrid extends StatelessWidget {
  final String monthLabel;
  final List<AssetEntity> photos;
  final void Function(AssetEntity) onPhotoTap;

  const PhotoMonthGrid({
    required this.monthLabel,
    required this.photos,
    required this.onPhotoTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: photos.length,
          itemBuilder: (ctx, i) {
            final asset = photos[i];
            return GestureDetector(
              onTap: () => onPhotoTap(asset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AssetEntityImage(
                  asset,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}