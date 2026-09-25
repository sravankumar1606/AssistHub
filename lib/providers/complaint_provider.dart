import 'dart:async';
import 'package:flutter/material.dart';
import 'package:assisthub/data/models/complaint_model.dart';
import 'package:assisthub/data/repositories/complaint_repository.dart';
import 'package:assisthub/providers/auth_provider.dart';

class ComplaintProvider extends ChangeNotifier {
  final ComplaintRepository _repository = ComplaintRepository();

  AuthProvider? _authProvider;
  List<ComplaintModel> _allComplaints = [];
  List<ComplaintModel> _myComplaints = [];
  String? _error;

  StreamSubscription<List<ComplaintModel>>? _allSubscription;
  StreamSubscription<List<ComplaintModel>>? _mySubscription;

  List<ComplaintModel> get allComplaints => _allComplaints;
  List<ComplaintModel> get myComplaints => _myComplaints;
  String? get error => _error;

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (authProvider.user != null) {
      _subscribeToMyComplaints(authProvider.user!.id);
    } else {
      _mySubscription?.cancel();
      _myComplaints = [];
    }
  }

  void _subscribeToMyComplaints(String userId) {
    _mySubscription?.cancel();
    _mySubscription = _repository.reporterComplaintsStream(userId).listen(
      (complaints) {
        _myComplaints = complaints;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// For the admin dashboard.
  void subscribeToAllComplaints() {
    _allSubscription?.cancel();
    _allSubscription = _repository.allComplaintsStream().listen(
      (complaints) {
        _allComplaints = complaints;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> submitComplaint({
    required String subject,
    required String description,
    String? bookingId,
  }) async {
    if (_authProvider?.user == null) return false;

    try {
      final user = _authProvider!.user!;
      final complaint = ComplaintModel(
        id: '',
        reporterId: user.id,
        reporterName: user.name,
        reporterRole: user.role.name,
        subject: subject,
        description: description,
        bookingId: bookingId,
        createdAt: DateTime.now(),
      );
      await _repository.submitComplaint(complaint);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resolveComplaint(String complaintId, String response) async {
    try {
      await _repository.resolveComplaint(complaintId, response);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _allSubscription?.cancel();
    _mySubscription?.cancel();
    super.dispose();
  }
}
