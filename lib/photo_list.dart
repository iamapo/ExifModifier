import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'photo_service.dart';
import 'photo_details_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:typed_data';


class PhotoList extends StatefulWidget {
  @override
  _PhotoListState createState() => _PhotoListState();
}

class _PhotoListState extends State<PhotoList> {
  @override
  void initState() {
    super.initState();
    _initializePhotos();
  }

  Future<void> _initializePhotos() async {
    final photoService = context.read<PhotoService>();
    final hasPermission = await photoService.requestPermissionsAndLoadPhotos();
    if (!hasPermission && mounted) {
      _showPermissionDialog();
    }
  }

  Future<void> _showPermissionDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.permissionDialogTitle),
        content: Text(AppLocalizations.of(context)!.permissionDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await PhotoManager.openSetting();
            },
            child: Text(AppLocalizations.of(context)!.openSettings),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.appTitle ?? 'Fotos ohne Standort'),
      ),
      body: Consumer<PhotoService>(
        builder: (context, photoService, child) {
          if (photoService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (photoService.photosWithoutLocation.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.noPhotosFound));
          }
          return _buildPhotoGrid(photoService);
        },
      ),
    );
  }

  Widget _buildPhotoGrid(PhotoService photoService) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: photoService.photosWithoutLocation.length,
        itemBuilder: (context, index) {
          return _buildPhotoItem(photoService.photosWithoutLocation[index]);
        },
      ),
    );
  }

  Widget _buildPhotoItem(AssetEntity photo) {
    final Future<Uint8List?> thumbnailFuture = photo.thumbnailDataWithSize(const ThumbnailSize(200, 200));

    return FutureBuilder<Uint8List?>(
      future: thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return _buildPhotoCard(photo, snapshot.data!);
        }
        return const Card(
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }


  Widget _buildPhotoCard(AssetEntity photo, Uint8List imageData) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoDetailsScreen(photo: photo),
          ),
        ),
        onLongPress: () => _showDeleteDialog(photo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(imageData, fit: BoxFit.cover),
            if (photo.title != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    photo.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(AssetEntity photo) async {
    final photoService = context.read<PhotoService>();
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deletePhotoTitle ?? 'Foto löschen'),
        content: Text(AppLocalizations.of(context)?.deletePhotoContent ?? 'Möchten Sie dieses Foto wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await photoService.deletePhoto(photo);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fehler beim Löschen des Fotos: $e')),
                );
              }
            },
            child: Text(AppLocalizations.of(context)?.delete ?? 'Löschen'),
          ),
        ],
      ),
    );
  }
}