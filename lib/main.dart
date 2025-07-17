import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'photo_service.dart';
import 'photo_list.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final photoService = PhotoService();

  runApp(
    ChangeNotifierProvider<PhotoService>.value(
      value: photoService,
      child: MyApp(photoService: photoService),
    ),
  );
}

class MyApp extends StatefulWidget {
  final PhotoService photoService;
  const MyApp({super.key, required this.photoService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void _onPhotoLocationSaved() {
    print('Reload photoservice');
    widget.photoService.loadPhotos();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate, // Add this line
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('de', ''), // German
      ],
      title: 'My App',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.black45,
        ),
      ),
      home: PhotoList(onPhotoLocationSaved: _onPhotoLocationSaved),
    );
  }
}
