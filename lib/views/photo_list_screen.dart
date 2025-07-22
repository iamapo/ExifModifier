import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../services/photo_service.dart';
import 'photo_details_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/PhotoListViewModel.dart';
import 'photo_details_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/exif_service.dart';
import '../services/photo_service.dart';

class PhotoListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PhotoListViewModel(service: PhotoService(exifService: ExifService())),
      child: Consumer<PhotoListViewModel>(
        builder: (_, vm, __) {
          return Scaffold(
            appBar: AppBar(title: Text('Fotos ohne Location')),
            body: vm.isLoading
                ? Center(child: CircularProgressIndicator())
                : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
              itemCount: vm.photos.length,
              itemBuilder: (_, i) {
                final photo = vm.photos[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoDetailsScreen(photo: photo, onSaved: () => vm.removePhoto(photo)),
                    ),
                  ),
                  child: AssetEntityImage(photo, fit: BoxFit.cover),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
