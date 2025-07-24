import 'package:flutter/material.dart';
import '../services/photo_service.dart';
import 'package:photo_manager/photo_manager.dart';

enum PhotoLoadState { loading, success, error, noPermission }

class PhotoListViewModel extends ChangeNotifier {
  final PhotoService service;
  List<AssetEntity> get photos => service.photos;
  bool get isLoading => service.isLoading;
  PhotoLoadState _state = PhotoLoadState.loading;
  PhotoLoadState get state => _state;
  String? _error;
  String? get error => _error;

  PhotoListViewModel({required this.service}) {
    service.addListener(() {
      notifyListeners();
    });
    load();
  }

  Future<void> load() async {
    final granted = await service.requestPermissions();
    if (!granted) {
      _state = PhotoLoadState.noPermission;
      notifyListeners();
      return;
    }
    try {
      await service.loadPhotos();
      _state = PhotoLoadState.success;
    } catch (e) {
      _error = e.toString();
      _state = PhotoLoadState.error;
    }
    notifyListeners();
  }

  void removePhoto(AssetEntity e) => service.remove(e);
}