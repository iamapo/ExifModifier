import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:exif/exif.dart';
import 'photo_details_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
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
        title: Text(AppLocalizations.of(context)?.appTitle ?? 'Photos without Location'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photosWithoutLocation.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noPhotosFound))
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
                  title: Text(photo.title ?? AppLocalizations.of(context)!.photoWithoutTitle),
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