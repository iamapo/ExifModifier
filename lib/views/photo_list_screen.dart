import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../services/photo_service.dart';
import '../utilities/grouping_utils.dart';
import 'photo_details_screen.dart';
import '../view_models/PhotoListViewModel.dart';
import '../services/exif_service.dart';

class PhotoListScreen extends StatelessWidget {
  const PhotoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          PhotoListViewModel(service: PhotoService(exifService: ExifService())),
      child: Consumer<PhotoListViewModel>(
        builder: (_, vm, __) {
          if (vm.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final grouped = groupByMonth(vm.photos);

          return Scaffold(
            appBar: AppBar(
              title: Text('Fotos ohne Location'),
              elevation: 0,
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: grouped.entries.map((entry) {
                final monthLabel = entry.key;
                final photosInMonth = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    // Raster mit 3 Spalten
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: photosInMonth.length,
                      itemBuilder: (ctx, i) {
                        final asset = photosInMonth[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoDetailsScreen(
                                photo: asset,
                                onSaved: () => vm.removePhoto(asset),
                              ),
                            ),
                          ),
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
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
