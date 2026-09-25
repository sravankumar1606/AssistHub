import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/storage_service.dart';
import 'auth_provider.dart';
import 'package:image_picker/image_picker.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  final StorageService _storageService = StorageService();

  AuthProvider? _authProvider;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (authProvider.user != null) {
      _user = authProvider.user;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    if (_authProvider?.user?.id == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _userRepository.getUser(_authProvider!.user!.id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (address != null) data['address'] = address;

      await _userRepository.updateUser(_user!.id, data);
      await refreshUser();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfileImage(XFile imageFile) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final imageUrl = await _storageService.uploadProfileImage(_user!.id, imageFile);
      await _userRepository.updateProfileImage(_user!.id, imageUrl);
      await refreshUser();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<XFile?> pickImage() async {
    return await _storageService.pickImage();
  }
}
