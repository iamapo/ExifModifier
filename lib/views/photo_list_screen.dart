import 'package:MapMyShot/views/widgets/photo_month_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
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
              title: Text(AppLocalizations.of(context)!.appTitle),
              elevation: 0,
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: grouped.entries.map((entry) {
                final monthLabel = entry.key;
                final photosInMonth = entry.value;
                return PhotoMonthGrid(
                  monthLabel: monthLabel,
                  photos: photosInMonth,
                  onPhotoTap: (photo) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoDetailsScreen(photo: photo, onSaved: () {  },),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
