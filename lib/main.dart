import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:exif/exif.dart';
import 'photo_details_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fotos ohne Standort',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', ''),
        Locale('en', ''),
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AssetEntity> _photosWithoutLocation = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoadPhotos();
  }

  Future<void> _requestPermissionsAndLoadPhotos() async {
    final PermissionState result = await PhotoManager.requestPermissionExtend();
    if (result.isAuth) {
      await _loadPhotos();
    } else {
      if (mounted) {
        await _showPermissionDialog();
      }
    }
  }

  Future<void> _showPermissionDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Zugriff erforderlich'),
        content: const Text('Bitte erlauben Sie den Fotozugriff, um fortzufahren.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await PhotoManager.openSetting();
            },
            child: const Text('Einstellungen öffnen'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    List<AssetEntity> photosWithoutLocation = [];
    for (var album in albums) {
      final List<AssetEntity> photos = await album.getAssetListPaged(page: 0, size: 50);
      for (var photo in photos) {
        if (await _photoHasNoLocation(photo)) {
          photosWithoutLocation.add(photo);
        }
      }
    }

    setState(() {
      _photosWithoutLocation = photosWithoutLocation;
      _isLoading = false;
    });
  }

  Future<bool> _photoHasNoLocation(AssetEntity photo) async {
    final Uint8List? imageData = await photo.originBytes;
    if (imageData == null) return true;
    try {
      final Map<String, IfdTag> exifData = await readExifFromBytes(imageData);
      final gpsLatitude = exifData['GPS GPSLatitude'];
      final gpsLongitude = exifData['GPS GPSLongitude'];
      return gpsLatitude == null || gpsLongitude == null;
    } catch (e) {
      print('Fehler beim Lesen der EXIF-Daten: $e');
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos ohne Standort'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photosWithoutLocation.isEmpty
          ? const Center(child: Text('Keine Fotos ohne Standort gefunden'))
          : ListView.builder(
        itemCount: _photosWithoutLocation.length,
        itemBuilder: (context, index) {
          final photo = _photosWithoutLocation[index];
          return FutureBuilder<Uint8List?>(
            future: photo.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                return ListTile(
                  leading: Image.memory(snapshot.data!),
                  title: Text(photo.title ?? 'Foto ohne Titel'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoDetailsScreen(photo: photo),
                      ),
                    );
                  },
                );
              }
              return const CircularProgressIndicator();
            },
          );
        },
      ),
    );
  }
}