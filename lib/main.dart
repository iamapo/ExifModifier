import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'photo_service.dart';
import 'photo_list.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final photoService = PhotoService();

  runApp(
    ChangeNotifierProvider<PhotoService>.value(
      value: photoService,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foto App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: PhotoList(),
    );
  }
}
