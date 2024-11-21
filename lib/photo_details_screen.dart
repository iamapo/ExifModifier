import 'package:exif_modifier/photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:geocoding/geocoding.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

class PhotoDetailsScreen extends StatefulWidget {
  final AssetEntity photo;

  const PhotoDetailsScreen({super.key, required this.photo});

  @override
  _PhotoDetailsScreenState createState() => _PhotoDetailsScreenState();
}

class _PhotoDetailsScreenState extends State<PhotoDetailsScreen> {
  static const platform =
      MethodChannel('io.flutter.flutter.app/photo_location');
  List<AssetEntity> similarPhotos = [];
  Map<AssetEntity, String> locationNames = {};

  @override
  void initState() {
    super.initState();
    _loadSimilarPhotos();
  }

  Future<String> _getLocationName(double? latitude, double? longitude) async {
    // Normalisiere die Koordinaten (0.0 wird zu null)
    latitude = latitude == 0.0 ? null : latitude;
    longitude = longitude == 0.0 ? null : longitude;

    if (latitude == null || longitude == null) {
      return 'Keine Location verfügbar';
    }

    print('_getLocationName Latitude: $latitude, Longitude: $longitude');

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String locality = place.locality ?? '';
        String country = place.country ?? '';
        return locality.isNotEmpty && country.isNotEmpty
            ? '$locality, $country'
            : 'Location gefunden';
      }
    } catch (e) {
      print('Fehler beim Abrufen der Location: $e');
    }

    return 'Location nicht gefunden';
  }

  Future<void> _loadSimilarPhotos() async {
    try {
      final similar =
          await findSimilarImages(widget.photo, const Duration(hours: 1));
      print(
          '_loadSimilarPhotos photo.createDateSecond ${widget.photo.thumbnailData} mit createDateTime ${widget.photo.createDateTime}');

      for (var photo in similar) {
        final latitude = photo.latitude;
        final longitude = photo.longitude;

        final locationName = await _getLocationName(latitude, longitude);
        print('Location für ${photo.title}: $locationName');
        locationNames[photo] = locationName;
      }

      setState(() {
        similarPhotos = similar;
      });
    } catch (e) {
      print('Fehler beim Laden ähnlicher Fotos: $e');
    }
  }

  static Future<List<AssetEntity>> findSimilarImages(
      AssetEntity targetImage, Duration timeThreshold) async {
    try {
      final albums =
          await PhotoManager.getAssetPathList(type: RequestType.image);
      if (albums.isEmpty) return [];

      final allImages =
          await albums.first.getAssetListRange(start: 0, end: 999999);
      final targetDateTime = targetImage.createDateTime;
      List<AssetEntity> similarImages = [];

      for (var image in allImages) {
        try {
          // Überspringe das Zielbild selbst
          if (image.id == targetImage.id) {
            continue;
          }

          final latitude = image.latitude;
          final longitude = image.longitude;

          // Normalisiere die Koordinaten
          final normalizedLat = latitude == 0.0 ? null : latitude;
          final normalizedLon = longitude == 0.0 ? null : longitude;

          if (normalizedLat != null && normalizedLon != null) {
            final imageDateTime = image.createDateTime;
            final difference = imageDateTime.difference(targetDateTime).abs();
            if (difference <= timeThreshold) {
              similarImages.add(image);
            }
          }
        } catch (e) {
          print('Fehler bei der Verarbeitung eines einzelnen Bildes: $e');
          continue;
        }
      }
      return similarImages;
    } catch (e) {
      print('Fehler in findSimilarImages: $e');
      return [];
    }
  }

  Future<void> _applyLocationFromPhoto(AssetEntity sourcePhoto) async {
    try {
      final latitude = sourcePhoto.latitude;
      final longitude = sourcePhoto.longitude;

      if (latitude == null ||
          longitude == null ||
          latitude == 0.0 ||
          longitude == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Keine Location im ausgewählten Bild gefunden')),
        );
        return;
      }

      final String? localId = widget.photo.id;
      if (localId == null) {
        throw Exception('Keine lokale ID für das Foto gefunden');
      }

      final bool success = await platform.invokeMethod('updatePhotoLocation', {
        'localId': localId,
        'latitude': latitude,
        'longitude': longitude,
      });

      if (success) {
        // Zeige eine Snackbar als Rückmeldung
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location übernommen!')),
        );

        final photoService = context.read<PhotoService>();
        await photoService.removePhoto(widget.photo);
        setState(() {
          locationNames[widget.photo] =
              locationNames[sourcePhoto] ?? 'Location aktualisiert';
        });

        Navigator.of(context).pop();
      } else {
        throw Exception('Location konnte nicht gesetzt werden');
      }
    } catch (e) {
      print('Fehler beim Übertragen der Location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Übertragen der Location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto Details')),
      body: Column(
        children: [
          // Hauptbild
          AspectRatio(
            aspectRatio: 1,
            child: AssetEntityImage(widget.photo),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Aufnahmedatum: ${widget.photo.createDateTime}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 20),
          Text('Ähnliche Bilder:'),
          Expanded(
            child: similarPhotos.isEmpty
                ? Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.8, // Angepasst für Location Text
                    ),
                    itemCount: similarPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = similarPhotos[index];
                      return GestureDetector(
                        onTap: () async {
                          // Übertrage die Location des ausgewählten Bildes auf das Hauptbild
                          await _applyLocationFromPhoto(photo);
                        },
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: AssetEntityImage(
                                    photo,
                                    isOriginal: false,
                                    thumbnailSize:
                                        const ThumbnailSize.square(200),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationNames[photo] ?? 'Lädt...',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    FutureBuilder<DateTime?>(
                                      future:
                                          Future.value(photo.createDateTime),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data?.toString() ??
                                              'Kein Datum',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
