import 'package:flutter/material.dart';
import '../services/photo_service.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoListViewModel extends ChangeNotifier {
  final PhotoService service;
  List<AssetEntity> get photos => service.photos;
  bool get isLoading => service.isLoading;

  PhotoListViewModel({required this.service}) {
    service.addListener(() {
      notifyListeners();
    });
    load();
  }

  Future<void> load() async {
    await service.requestPermissions();
    await service.loadPhotos();
  }

  void removePhoto(AssetEntity e) => service.remove(e);
}