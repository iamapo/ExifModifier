import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Global EXIF data cache
final Map<AssetEntity, Map<String, IfdTag>> _exifDataCache = {};

class PhotoDetailsScreen extends StatefulWidget {
  final AssetEntity photo;
  final VoidCallback onLocationSaved;

  const PhotoDetailsScreen({
    super.key,
    required this.photo,
    required this.onLocationSaved,
  });

  @override
  _PhotoDetailsScreenState createState() => _PhotoDetailsScreenState();
}

class _PhotoDetailsScreenState extends State<PhotoDetailsScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  String? _selectedTimeRange = '1 hour';

  final List<String> _timeRangeOptions = [
    '1 hour',
    '4 hours',
    '12 hours',
  ];

  Duration _getTimeRangeDuration(String? timeRange) {
    switch (timeRange) {
      case '1 hour':
        return const Duration(hours: 1);
      case '4 hours':
        return const Duration(hours: 4);
      case '12 hours':
        return const Duration(hours: 12);
      default:
        return const Duration(hours: 1); // Default to 1 hour if invalid
    }
  }

  static const platform =
  MethodChannel('io.flutter.flutter.app/photo_location');
  List<AssetEntity> similarPhotos = [];
  Map<AssetEntity, String> locationNames = {};
  Map<String, IfdTag>? _mainPhotoExifData; // Store EXIF data for main photo

  @override
  void initState() {
    super.initState();
    _loadMainPhotoExifData(); // Load EXIF data for main photo
    _loadSimilarPhotos();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2229498003007416~8867984154', // Test-AdUnit ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // Load EXIF data for the main photo
  Future<void> _loadMainPhotoExifData() async {
    final exifData = await _getExifData(widget.photo);
    setState(() {
      _mainPhotoExifData = exifData;
    });
  }

  // Get EXIF data from cache or fetch if not cached
  Future<Map<String, IfdTag>?> _getExifData(AssetEntity photo) async {
    if (_exifDataCache.containsKey(photo)) {
      return _exifDataCache[photo];
    }

    final file = await photo.file;
    if (file != null) {
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);
      _exifDataCache[photo] = exifData; // Cache the EXIF data
      return exifData;
    }

    return null;
  }

  // Get location name from EXIF data
  Future<String> _getLocationName(AssetEntity photo) async {
    final exifData = await _getExifData(photo);
    final latitudeDms = exifData?['GPS GPSLatitude']?.printable;
    final longitudeDms = exifData?['GPS GPSLongitude']?.printable;

    final latitude = _convertDmsToDecimal(latitudeDms);
    final longitude = _convertDmsToDecimal(longitudeDms);

    if (latitude == null || longitude == null) {
      return 'Keine Location verfügbar';
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locality = place.locality ?? '';
        final country = place.country ?? '';
        return locality.isNotEmpty && country.isNotEmpty
            ? '$locality, $country'
            : 'Location found';
      }
    } catch (e) {
      print('Fehler beim Abrufen der Location: $e');
    }

    return 'Location nicht gefunden';
  }

  Future<void> _loadSimilarPhotos() async {
    try {
      final Duration timeThreshold = _getTimeRangeDuration(_selectedTimeRange);
      final similar = await findSimilarImages(widget.photo, timeThreshold);

      List<Future<void>> fetchLocationTasks = [];
      for (var photo in similar) {
        fetchLocationTasks.add(() async {
          final locationName = await _getLocationName(photo);
          setState(() {
            locationNames[photo] = locationName;
          });
        }());
      }

      await Future.wait(fetchLocationTasks); // Warte auf alle parallelen Aufgaben
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
      // Definiere den Zeitbereich
      final DateTime minDate = targetImage.createDateTime.subtract(timeThreshold);
      final DateTime maxDate = targetImage.createDateTime.add(timeThreshold);

      // Hole Alben mit Filterung
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          containsPathModified: false,
          createTimeCond: DateTimeCond(
            min: minDate,
            max: maxDate,
          ),
        ),
      );

      if (albums.isEmpty) return [];

      // Lade alle Bilder innerhalb des Zeitraums
      final List<AssetEntity> allImages =
      await albums.first.getAssetListRange(start: 0, end: 999999);
      final DateTime targetDateTime = targetImage.createDateTime;
      List<AssetEntity> similarImages = [];

      // Hole EXIF-Daten für das Zielbild
      final targetFile = await targetImage.file;
      final targetExifData = targetFile != null
          ? await readExifFromBytes(await targetFile.readAsBytes())
          : null;
      final targetLatitude = targetExifData?['GPS GPSLatitude']?.printable;
      final targetLongitude = targetExifData?['GPS GPSLongitude']?.printable;

      print('Ziel-EXIF-Daten: $targetLatitude $targetLongitude');

      for (var image in allImages) {
        try {
          // Überspringe das Zielbild selbst
          if (image.id == targetImage.id) {
            continue;
          }

          // Hole EXIF-Daten für das aktuelle Bild
          final imageFile = await image.file;
          final imageExifData = imageFile != null
              ? await readExifFromBytes(await imageFile.readAsBytes())
              : null;
          final imageLatitude = imageExifData?['GPS GPSLatitude']?.printable;
          final imageLongitude = imageExifData?['GPS GPSLongitude']?.printable;

          print('Bild-EXIF-Daten: ${image.id} $imageLatitude $imageLongitude');

          // Vergleiche die EXIF-Koordinaten
          if (
              imageLatitude != null &&
              imageLongitude != null) {
            similarImages.add(image); // Füge Bild hinzu, wenn Standort übereinstimmt
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
      final imageFile = await sourcePhoto.file;

      final imageExifData = imageFile != null
          ? await readExifFromBytes(await imageFile.readAsBytes())
          : null;
      final latitudeDms = imageExifData?['GPS GPSLatitude']?.printable;
      final longitudeDms = imageExifData?['GPS GPSLongitude']?.printable;

      final latitude = _convertDmsToDecimal(latitudeDms);
      final longitude = _convertDmsToDecimal(longitudeDms);

      if (latitude == null || longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorNoLocationDataFound)),
        );
        return;
      }

      print('Konvertierte Koordinaten: Latitude: $latitude, Longitude: $longitude');

      final String? filePath = await getPhotoFilePath(widget.photo);
      if (filePath == null || filePath.isEmpty) {
        throw Exception('Dateipfad konnte nicht abgerufen werden');
      }

      print('Übergebe an Native: filePath=$filePath, latitude=$latitude, longitude=$longitude');

      final bool success = await platform.invokeMethod('updatePhotoLocation', {
        'filePath': filePath,
        'latitude': latitude,
        'longitude': longitude,
      });

      if (success) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.locationSuccess)),
        );
        Navigator.of(context).pop();
        widget.onLocationSaved(); // Benachrichtige, dass das Foto aktualisiert wurde
      } else {
        throw Exception('Location konnte nicht gesetzt werden');
      }
    } catch (e) {
      print('Fehler beim Übertragen der Location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorSendingLocation)),
      );
    }
  }


  Future<String?> getPhotoFilePath(AssetEntity photo) async {
    final file = await photo.file;
    return file?.path;
  }

  double? _convertDmsToDecimal(String? dmsString) {
    if (dmsString == null) return null;
    try {
      // DMS ist oft als eine Liste von Werten wie "[53, 33, 5123/100]"
      // Wir entfernen die eckigen Klammern und teilen in Teile
      dmsString = dmsString.replaceAll(RegExp(r'[\[\]]'), '');
      final parts = dmsString.split(', ').map((part) {
        if (part.contains('/')) {
          // Wandelt Brüche wie "5123/100" in Gleitkommazahlen um
          final fractionParts = part.split('/');
          return double.parse(fractionParts[0]) / double.parse(fractionParts[1]);
        }
        return double.parse(part);
      }).toList();

      if (parts.length != 3) return null;

      // Konvertiere DMS zu Dezimalgrad
      final degrees = parts[0];
      final minutes = parts[1];
      final seconds = parts[2];
      return degrees + (minutes / 60) + (seconds / 3600);
    } catch (e) {
      print('Fehler beim Konvertieren von DMS zu Dezimal: $e');
      return null;
    }
  }

  Future<bool> _updatePhotoLocation(String localId, double? latitude, double? longitude) async {
    try {
      final bool success = await platform.invokeMethod('updatePhotoLocation', {
        'localId': localId,
        'latitude': latitude,
        'longitude': longitude,
      });
      return success;
    } catch (e) {
      print('Fehler beim Aktualisieren der Location: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppLocalizations.of(context)!.photoDetails),
        actions: [
          DropdownButton<String>(
            value: _selectedTimeRange,
            onChanged: (String? newValue) {
              setState(() {
                _selectedTimeRange = newValue;
                _loadSimilarPhotos();
              });
            },
            underline: Container(),
            items: _timeRangeOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AssetEntityImage(widget.photo),
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
              ),
              const SizedBox(height: 20),
              if (similarPhotos.isNotEmpty) // Conditional expression
                Text(AppLocalizations.of(context)!.similarPictures),
              Expanded(
                child: similarPhotos.isEmpty
                    ? Center(
                  child: Text(AppLocalizations.of(context)!.noSimilarPictures,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: similarPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = similarPhotos[index];
                    return GestureDetector(
                      onTap: () async {
                        await _applyLocationFromPhoto(photo);
                      },
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
                              child: FutureBuilder<String>(
                                future: _getLocationName(photo),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      snapshot.data!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Text(AppLocalizations.of(context)!.error);
                                  } else {
                                    return const CircularProgressIndicator();
                                  }
                                },
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.white, // Hintergrundfarbe für das Banner
              width: double.infinity,
              height: 50, // Höhe des Werbebanners
              child: AdWidget(ad: _bannerAd!), // Zeigt das Banner an
            ),
          ),
        ],
      ),
    );
  }
}
