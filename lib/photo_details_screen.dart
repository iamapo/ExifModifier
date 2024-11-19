import 'dart:typed_data';  // Fügen Sie diesen Import hinzu
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PhotoDetailsScreen extends StatelessWidget {
  final AssetEntity photo;

  const PhotoDetailsScreen({Key? key, required this.photo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.photoDetails),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getPhotoDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.errorLoadingDetails));
          }
          if (!snapshot.hasData) {
            return Center(child: Text(AppLocalizations.of(context)!.noDataAvailable));
          }

          final details = snapshot.data!;
          return SingleChildScrollView(  // Fügt Scrolling hinzu
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details['thumbnailData'] != null)
                    Image.memory(details['thumbnailData'] as Uint8List),
                  SizedBox(height: 16),
                  Text('Titel: ${details['title'] ?? 'Kein Titel'}'),
                  Text('Datum: ${details['createDateTime'] ?? 'Kein Datum'}'),
                  Text('Größe: ${details['width']} x ${details['height']} Pixel'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getPhotoDetails() async {
    try {
      final Uint8List? thumbnailData = await photo.thumbnailData;
      return {
        'thumbnailData': thumbnailData,
        'title': photo.title,
        'createDateTime': photo.createDateTime.toString(),
        'width': photo.width,
        'height': photo.height,
      };
    } catch (e) {
      print('Fehler beim Laden der Fotodetails: $e');
      rethrow;
    }
  }
}