import 'dart:async';
import 'package:flutter/material.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/data/repositories/employee_repository.dart';
import 'package:assisthub/data/services/storage_service.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class EmployeeProvider extends ChangeNotifier {
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final StorageService storageService = StorageService();

  AuthProvider? _authProvider;
  EmployeeModel? _currentEmployee;
  List<EmployeeModel> _employees = [];
  List<EmployeeModel> _filteredEmployees = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedCategory;
  StreamSubscription<List<EmployeeModel>>? _employeesSubscription;
  StreamSubscription<EmployeeModel?>? _currentEmployeeSubscription;

  EmployeeModel? get currentEmployee => _currentEmployee;
  /// Customer-facing employee list — always excludes the current user's
  /// own employee profile (relevant for dual-role accounts), so an
  /// employee never sees themselves while browsing as a customer.
  List<EmployeeModel> get employees {
    final list = _filteredEmployees.isNotEmpty ? _filteredEmployees : _employees;
    final selfUserId = _authProvider?.user?.id;
    if (selfUserId == null) return list;
    return list.where((e) => e.userId != selfUserId).toList();
  }
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;

  void attachAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (authProvider.isEmployee && authProvider.user != null) {
      loadCurrentEmployee(authProvider.user!.id);
    } else {
      _currentEmployeeSubscription?.cancel();
      _currentEmployee = null;
      notifyListeners();
    }
  }
  

  Future<void> loadCurrentEmployee(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final employeeData = await _employeeRepository.getEmployeeByUserId(userId);
      _currentEmployee = employeeData;
      _subscribeToCurrentEmployee(employeeData?.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error loading current employee: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void subscribeToEmployees() {
    _employeesSubscription?.cancel();
    _employeesSubscription = _employeeRepository.employeesStream().listen(
      (employees) {
        _employees = employees;
        _applyFilters();
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void subscribeToEmployeesByCategory(String category) {
    _selectedCategory = category;
    _employeesSubscription?.cancel();
    _employeesSubscription = _employeeRepository.employeesByCategoryStream(category).listen(
      (employees) {
        _employees = employees;
        _filteredEmployees = [];
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void _applyFilters() {
    if (_selectedCategory != null) {
      _filteredEmployees = _employees
          .where((e) => e.serviceCategory == _selectedCategory)
          .toList();
    } else {
      _filteredEmployees = [];
    }
  }

  void clearCategoryFilter() {
    _selectedCategory = null;
    _filteredEmployees = [];
    subscribeToEmployees();
  }

  Future<List<EmployeeModel>> getTopRatedEmployees() async {
    final results = await _employeeRepository.getTopRatedEmployees();
    final selfUserId = _authProvider?.user?.id;
    if (selfUserId == null) return results;
    return results.where((e) => e.userId != selfUserId).toList();
  }

  Future<List<EmployeeModel>> searchEmployees(String query) async {
    if (query.isEmpty) return employees;
    final results = await _employeeRepository.searchEmployees(query);
    final selfUserId = _authProvider?.user?.id;
    if (selfUserId == null) return results;
    return results.where((e) => e.userId != selfUserId).toList();
  }

  Future<bool> registerAsEmployee({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String serviceCategory,
    required String serviceDetails,
    required int experienceYears,
    required double hourlyRate,
    XFile? profileImage,
    List<PlatformFile>? documents,
    XFile? video,
  }) async {
    if (_authProvider?.user == null) {
      _error = 'You must be signed in before completing employee registration.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _authProvider!.user!.id;

      String? profileImageUrl;
      if (profileImage != null) {
        try {
          profileImageUrl = await storageService
              .uploadProfileImage(userId, profileImage)
              .timeout(const Duration(seconds: 20));
        } catch (e) {
          debugPrint('Profile image upload skipped: $e');
        }
      }

      // Upload verification documents (images or PDFs)
      final documentUrls = <String>[];
      if (documents != null) {
        for (final doc in documents) {
          if (doc.bytes == null) continue;
          try {
            final url = await _employeeRepository.uploadEmployeeDocument(
              employeeUserId: userId,
              fileName: doc.name,
              bytes: doc.bytes!,
              contentType: _contentTypeForExtension(doc.extension),
            );
            documentUrls.add(url);
          } catch (e) {
            debugPrint('Document upload failed for ${doc.name}: $e');
          }
        }
      }

      // Upload verification video
      String? videoUrl;
      if (video != null) {
        try {
          videoUrl = await _employeeRepository.uploadEmployeeVideo(
            employeeUserId: userId,
            videoFile: video,
          );
        } catch (e) {
          debugPrint('Video upload failed: $e');
        }
      }

      final now = DateTime.now();
      final employee = EmployeeModel(
        id: userId,
        userId: userId,
        name: name,
        email: email,
        phone: phone,
        address: address,
        profileImage: profileImageUrl,
        serviceCategory: serviceCategory,
        serviceDetails: serviceDetails,
        experienceYears: experienceYears,
        hourlyRate: hourlyRate,
        verificationStatus: VerificationStatus.pending,
        documentUrls: documentUrls,
        videoUrl: videoUrl,
        createdAt: now,
        updatedAt: now,
      );

      await _employeeRepository.createEmployee(employee);
      await _authProvider!.updateUserRole(UserRole.employee);
      _currentEmployee = employee;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String? _contentTypeForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return null;
    }
  }

  Future<XFile?> pickVideo() async {
    final picker = ImagePicker();
    return await picker.pickVideo(source: ImageSource.gallery);
  }

  /// Uploads a work sample video and adds it to the employee's public
  /// portfolio (workVideoUrls) — separate from the private verification
  /// video admins review. Returns true on success.
  Future<bool> addWorkVideo(XFile videoFile) async {
    if (_currentEmployee == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final videoUrl = await _employeeRepository.uploadEmployeeVideo(
        employeeUserId: _currentEmployee!.userId,
        videoFile: videoFile,
      );
      await _employeeRepository.addWorkVideo(_currentEmployee!.id, videoUrl);
      _currentEmployee = _currentEmployee!.copyWith(
        workVideoUrls: [..._currentEmployee!.workVideoUrls, videoUrl],
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeWorkVideo(String videoUrl) async {
    if (_currentEmployee == null) return false;

    try {
      await _employeeRepository.removeWorkVideo(_currentEmployee!.id, videoUrl);
      _currentEmployee = _currentEmployee!.copyWith(
        workVideoUrls:
            _currentEmployee!.workVideoUrls.where((url) => url != videoUrl).toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<PlatformFile>> pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    return result?.files ?? [];
  }

  // --- Admin: verification workflow ---

  List<EmployeeModel> _allEmployeesForAdmin = [];
  StreamSubscription<List<EmployeeModel>>? _adminEmployeesSubscription;

  List<EmployeeModel> get pendingEmployees => _allEmployeesForAdmin
      .where((e) => e.verificationStatus == VerificationStatus.pending)
      .toList();
  List<EmployeeModel> get approvedEmployees => _allEmployeesForAdmin
      .where((e) => e.verificationStatus == VerificationStatus.approved)
      .toList();
  List<EmployeeModel> get rejectedEmployees => _allEmployeesForAdmin
      .where((e) => e.verificationStatus == VerificationStatus.rejected)
      .toList();

  void subscribeToPendingEmployees() {
    _adminEmployeesSubscription?.cancel();
    _adminEmployeesSubscription =
        _employeeRepository.allEmployeesForAdminStream().listen(
      (employees) {
        _allEmployeesForAdmin = employees;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> approveEmployee(String employeeId) async {
    try {
      await _employeeRepository.approveEmployee(employeeId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectEmployee(String employeeId, String reason) async {
    try {
      await _employeeRepository.rejectEmployee(employeeId, reason);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEmployee(Map<String, dynamic> data) async {
    if (_currentEmployee == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _employeeRepository.updateEmployee(_currentEmployee!.id, data);
      await loadCurrentEmployee(_authProvider!.user!.id);
      _isLoading = false;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAvailability(bool isAvailable) async {
    if (_currentEmployee == null) return false;

    try {
      await _employeeRepository.updateAvailability(_currentEmployee!.id, isAvailable);
      _currentEmployee = _currentEmployee!.copyWith(isAvailable: isAvailable);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<XFile?> pickImage() async {
    return await storageService.pickImage();
  }

  void _subscribeToCurrentEmployee(String? employeeId) {
    _currentEmployeeSubscription?.cancel();
    if (employeeId == null || employeeId.isEmpty) return;

    _currentEmployeeSubscription =
        _employeeRepository.employeeStream(employeeId).listen(
      (employee) {
        _currentEmployee = employee;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _employeesSubscription?.cancel();
    _currentEmployeeSubscription?.cancel();
    _adminEmployeesSubscription?.cancel();
    super.dispose();
  }
}
