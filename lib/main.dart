import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:photo_manager/photo_manager.dart';
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
  const HomePage({super.key});

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

  Future<void> _deletePhoto(AssetEntity photo) async {
    final result = await PhotoManager.editor.deleteWithIds([photo.id]);
    if (result.isNotEmpty) {
      setState(() {
        _photosWithoutLocation.remove(photo);
      });
    }
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
      builder: (BuildContext context) =>
          AlertDialog(
            title: Text(AppLocalizations.of(context)!.permissionDialogTitle),
            content: Text(
                AppLocalizations.of(context)!.permissionDialogContent),
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
      final List<AssetEntity> photos = await album.getAssetListPaged(
          page: 0, size: 50);
      for (var photo in photos) {
        if (await _photoHasNoLocation(photo)) {
          photosWithoutLocation.add(photo);
        }
      }
    }

    photosWithoutLocation.sort((a, b) =>
        b.createDateTime.compareTo(a.createDateTime));

    setState(() {
      _photosWithoutLocation = photosWithoutLocation;
      _isLoading = false;
    });
  }

  Future<bool> _photoHasNoLocation(AssetEntity photo) async {
    final latitude = _normalizeCoordinate(await photo.latitude);
    final longitude = _normalizeCoordinate(await photo.longitude);

    print('Lade Bild: $latitude $longitude ${photo.title}');
    return latitude == null || longitude == null;
  }

  double? _normalizeCoordinate(double? coordinate) {
    return coordinate == 0.0 ? null : coordinate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.appTitle ?? 'Fotos ohne Standort'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photosWithoutLocation.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noPhotosFound))
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _photosWithoutLocation.length,
          itemBuilder: (context, index) {
            final photo = _photosWithoutLocation[index];
            return FutureBuilder<Uint8List?>(
              future: photo.thumbnailDataWithSize(
                const ThumbnailSize(200, 200),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PhotoDetailsScreen(photo: photo),
                          ),
                        );
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)!
                                .deletePhotoTitle),
                            content: Text(AppLocalizations.of(context)!
                                .deletePhotoContent),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                child: Text(
                                    AppLocalizations.of(context)!.cancel),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _deletePhoto(photo);
                                },
                                child: Text(
                                    AppLocalizations.of(context)!.delete),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Bild
                          Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          ),
                          // Optional: Titel-Overlay am unteren Rand
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
                return const Card(
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}