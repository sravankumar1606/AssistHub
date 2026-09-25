import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:assisthub/data/models/user_model.dart';
import 'package:assisthub/data/repositories/auth_repository.dart';
import 'package:assisthub/data/services/notification_service.dart';

// 1. Explicitly defined Enum outside the provider class scope to resolve compilation errors
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  // --- Dependencies ---
  AuthRepository _authRepository;

  // --- State Variables ---
  AuthState _state = AuthState.initial;
  bool _isAuthenticated = false;
  UserModel? _user; 
  String? _error;
  UserRole? _selectedRole;
  String? _phoneVerificationId;
  int? _phoneResendToken;
  firebase_auth.ConfirmationResult? _phoneConfirmationResult;
  bool _isOtpSent = false;

  // --- Getters ---
  AuthState get state => _state;
  bool get isAuthenticated => _isAuthenticated;
  UserModel? get user => _user; 
  String? get error => _error;
  UserRole? get selectedRole => _selectedRole;
  bool get isOtpSent => _isOtpSent;
bool get isLoading => _state == AuthState.loading || _state == AuthState.initial;

bool get isEmployee => _user?.role == UserRole.employee;
bool get isCustomer => _user?.role == UserRole.customer;
bool get isAdmin => _user?.role == UserRole.admin;
bool get isDualRole => _user?.isDualRole ?? false;
  // --- Constructor ---
  AuthProvider(this._authRepository) {
    _initAuth();
  }

  void updateAuth(AuthRepository authRepository) {
    _authRepository = authRepository;
  }

  // --- Base Auth Stream Initialization ---
  void _initAuth() {
    print("AuthProvider Initialized");
    
    // Safely monitor underlying Firebase account status mutations
    firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
      if (firebaseUser != null) {
        _isAuthenticated = true;
        await _loadUserData(firebaseUser.uid);
      } else {
        _user = null;
        _isAuthenticated = false;
        _state = AuthState.unauthenticated;
        notifyListeners();
      }
    });
  }

  // --- Fetch Custom Data Profile Documents ---
  Future<void> _loadUserData(String userId) async {
    try {
      final userDoc = await _authRepository.getUserDocument(userId);
      if (userDoc != null) {
        _user = userDoc;
        // Migrate old users — add roles field if missing
        if (userDoc.roles.isEmpty || userDoc.roles.length == 1) {
          await _authRepository.addRoleToUser(userId, userDoc.role);
        }
        _state = AuthState.authenticated;
        
        final token = await NotificationService.getToken();
        if (token != null) {
          await _authRepository.updateFcmToken(userId, token);
        }
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  void setSelectedRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  Future<void> updateUserRole(UserRole role) async {
    if (_user == null) return;

    await _authRepository.updateUserRole(_user!.id, role);
    _user = _user!.copyWith(
      role: role,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }
  Future<bool> forgotPassword(String email) async {
  try {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    await _authRepository.resetPassword(email);

    _state = AuthState.unauthenticated;
    notifyListeners();
    return true;
  } catch (e) {
    _state = AuthState.error;
    _error = e.toString();
    notifyListeners();
    return false;
  }
}
Future<bool> resendVerificationEmail() async {
  try {
    await firebase_auth.FirebaseAuth.instance.currentUser?.sendEmailVerification();
    return true;
  } catch (e) {
    _error = e.toString();
    notifyListeners();
    return false;
  }
}
  // --- Email Log-In Handling ---
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _state = AuthState.loading;
      _error = null;
      notifyListeners();

     final credential = await _authRepository.signInWithEmail(email, password);

    // Block unverified emails
    if (!credential.user!.emailVerified) {
    await firebase_auth.FirebaseAuth.instance.signOut();
    _state = AuthState.error;
    _error = 'Please verify your email first. Check your inbox.';
    notifyListeners();
    return false;
    }

await _loadUserData(credential.user!.uid);
return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _state = AuthState.error;
      _error = _getAuthErrorMessage(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Separate sign-in path for the Admin Login screen only. Admin
  /// accounts are created manually in Firebase Console, so there is no
  /// self-signup step that would trigger a verification email in the
  /// first place — skipping that check here, but still requiring the
  /// account's Firestore role to actually be 'admin' before allowing in.
  Future<bool> signInAdmin(String email, String password) async {
    try {
      _state = AuthState.loading;
      _error = null;
      notifyListeners();

      final credential = await _authRepository.signInWithEmail(email, password);
      await _loadUserData(credential.user!.uid);

      if (_user?.role != UserRole.admin) {
        await firebase_auth.FirebaseAuth.instance.signOut();
        _user = null;
        _state = AuthState.error;
        _error = 'This account does not have admin access.';
        notifyListeners();
        return false;
      }

      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _state = AuthState.error;
      _error = _getAuthErrorMessage(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- Account Sign-Up Handling ---
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    try {
      _state = AuthState.loading;
      _error = null;
      notifyListeners();

      final credential = await _authRepository.signUpWithEmail(email, password);
      final now = DateTime.now();
      
      final newUser = UserModel(
        id: credential.user!.uid,
        email: email,
        name: name,
        role: _selectedRole ?? UserRole.customer,
        createdAt: now,
        updatedAt: now,
      );

      await _authRepository.createUserDocument(newUser);

// Send verification email
await firebase_auth.FirebaseAuth.instance.currentUser?.sendEmailVerification();

_user = newUser;
_state = AuthState.unauthenticated;
_error = 'A verification email has been sent to $email. Please verify before logging in.';
notifyListeners();
// Sign out until verified
await firebase_auth.FirebaseAuth.instance.signOut();
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _state = AuthState.error;
      _error = _getAuthErrorMessage(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- Google Authentication Flow (Native) ---

  // Inside your AuthProvider class...
  Future<bool> signInWithGoogle() async {
    try {
      _state = AuthState.loading;
      _error = null;
      notifyListeners();

      final credential = await _authRepository.signInWithGoogle();
      if (credential == null || credential.user == null) {
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }

      final userId = credential.user!.uid;
      final exists = await _authRepository.checkUserExists(userId);

      if (exists) {
        await _loadUserData(userId);
      } else {
        final firebaseUser = credential.user!;
        final now = DateTime.now();
        final newUser = UserModel(
          id: userId,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'User',
          profileImage: firebaseUser.photoURL,
          role: _selectedRole ?? UserRole.customer,
          createdAt: now,
          updatedAt: now,
        );

        await _authRepository.createUserDocument(newUser);
        _user = newUser;
        _isAuthenticated = true;
        _state = AuthState.authenticated;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPhoneOtp(String phoneNumber) async {
    final completer = Completer<bool>();

    try {
      final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
      if (normalizedPhoneNumber == null) {
        _state = AuthState.error;
        _error = 'Enter a valid phone number with country code, for example +919876543210.';
        _isOtpSent = false;
        notifyListeners();
        return false;
      }

      _state = AuthState.loading;
      _error = null;
      notifyListeners();

      if (kIsWeb) {
        _phoneConfirmationResult =
            await _authRepository.signInWithPhoneNumber(
          normalizedPhoneNumber,
        );
        _isOtpSent = true;
        _state = AuthState.unauthenticated;
        notifyListeners();
        return true;
      }

      await _authRepository.verifyPhoneNumber(
        phoneNumber: normalizedPhoneNumber,
        forceResendingToken: _phoneResendToken,
        verificationCompleted: (credential) async {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        verificationFailed: (e) {
          _state = AuthState.error;
          _error = _getAuthErrorMessage(e.code, e.message);
          _isOtpSent = false;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        codeSent: (verificationId, resendToken) {
          _phoneVerificationId = verificationId;
          _phoneResendToken = resendToken;
          _isOtpSent = true;
          _state = AuthState.unauthenticated;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _phoneVerificationId = verificationId;
        },
      );

      return await completer.future;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _state = AuthState.error;
      _error = _getAuthErrorMessage(e.code, e.message);
      _isOtpSent = false;
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
      _isOtpSent = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithPhoneOtp(String smsCode) async {
    try {
      if (!kIsWeb && _phoneVerificationId == null) {
        _error = 'Please request an OTP first.';
        notifyListeners();
        return false;
      }
      if (kIsWeb && _phoneConfirmationResult == null) {
        _error = 'Please request an OTP first.';
        notifyListeners();
        return false;
      }

      _state = AuthState.loading;
      _error = null;
      notifyListeners();

      final userCredential = kIsWeb
          ? await _phoneConfirmationResult!.confirm(smsCode)
          : await _authRepository.signInWithCredential(
              _authRepository.phoneCredential(
                verificationId: _phoneVerificationId!,
                smsCode: smsCode,
              ),
            );
      final userId = userCredential.user!.uid;
      final exists = await _authRepository.checkUserExists(userId);

      if (!exists) {
        _state = AuthState.unauthenticated;
        _error = 'No account found for this phone number. Please sign up first.';
        notifyListeners();
        return false;
      }

      await _loadUserData(userId);
      _isOtpSent = false;
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _state = AuthState.error;
      _error = _getAuthErrorMessage(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithPhoneOtp(String phoneNumber, String name, String smsCode) async {
    try {
      if (!kIsWeb && _phoneVerificationId == null) {
        _error = 'Please request an OTP first.';
        notifyListeners();
        return false;
      }
      if (kIsWeb && _phoneConfirmationResult == null) {
        _error = 'Please request an OTP first.';
        notifyListeners();
        return false;
      }

      _state = AuthState.loading;
      _error = null;
      notifyListeners();

      final userCredential = kIsWeb
          ? await _phoneConfirmationResult!.confirm(smsCode)
          : await _authRepository.signInWithCredential(
              _authRepository.phoneCredential(
                verificationId: _phoneVerificationId!,
                smsCode: smsCode,
              ),
            );
      final userId = userCredential.user!.uid;
      final exists = await _authRepository.checkUserExists(userId);

      if (exists) {
        await _loadUserData(userId);
        _isOtpSent = false;
        return true;
      }

      final now = DateTime.now();
      final newUser = UserModel(
        id: userId,
        email: userCredential.user?.email ?? '',
        name: name,
        phone: _normalizePhoneNumber(phoneNumber) ?? phoneNumber.trim(),
        role: _selectedRole ?? UserRole.customer,
        createdAt: now,
        updatedAt: now,
      );

      await _authRepository.createUserDocument(newUser);
      _user = newUser;
      _isAuthenticated = true;
      _isOtpSent = false;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _state = AuthState.error;
      _error = _getAuthErrorMessage(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- Google Authentication Flow (Web UI Popup Trigger) ---
  Future<void> signInWithGoogleWeb() async {
    await signInWithGoogle();
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    _state = AuthState.loading;
    notifyListeners();

    await _authRepository.signOut();
    
    _user = null;
    _selectedRole = null;
    _phoneVerificationId = null;
    _phoneResendToken = null;
    _isOtpSent = false;
    _isAuthenticated = false;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }
  // --- Dual Role: Switch active session role ---
Future<void> switchRole(UserRole newRole) async {
  if (_user == null) return;
  if (!_user!.roles.contains(newRole)) {
    _error = 'You do not have access to this role.';
    notifyListeners();
    return;
  }
  _user = _user!.copyWith(role: newRole);
  await _authRepository.updateUserRole(_user!.id, newRole);
  notifyListeners();
}

// --- Dual Role: Register existing user for a new role ---
Future<bool> registerAsRole(UserRole newRole, {Map<String, dynamic>? roleData}) async {
  if (_user == null) return false;

  try {
    _state = AuthState.loading;
    notifyListeners();

    // Check if already has this role
    final alreadyHasRole = await _authRepository.userHasRole(_user!.id, newRole);
    if (alreadyHasRole) {
      _error = 'You are already registered as ${newRole.name}.';
      _state = AuthState.authenticated;
      notifyListeners();
      return false;
    }

    // Add role to user's roles list
    await _authRepository.addRoleToUser(_user!.id, newRole);

    // Create role-specific sub-document
    await _authRepository.createRoleDocument(
      _user!.id,
      newRole,
      roleData ?? {'userId': _user!.id},
    );

    // Update local user model
    final updatedRoles = [..._user!.roles, newRole];
    _user = _user!.copyWith(roles: updatedRoles);

    _state = AuthState.authenticated;
    notifyListeners();
    return true;
  } catch (e) {
    _error = e.toString();
    _state = AuthState.error;
    notifyListeners();
    return false;
  }
}

// --- Dual Role: Check if user has a specific role ---
bool hasRole(UserRole role) => _user?.roles.contains(role) ?? false;

// --- Dual Role: Load after login — show role picker if dual role ---
bool get needsRolePicker => (_user?.isDualRole ?? false) && _selectedRole == null;

  Future<bool> resetPassword(String email) async {
    try {
      await _authRepository.resetPassword(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  String _getAuthErrorMessage(String code, [String? message]) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'invalid-phone-number':
        return 'Enter a valid phone number with country code.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check the code and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'captcha-check-failed':
        return 'Captcha verification failed. Refresh the page and try again.';
      case 'app-not-authorized':
        return 'This domain is not authorized in Firebase Authentication.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled in Firebase Authentication.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Try again later or use a Firebase test phone number.';
      case 'missing-phone-number':
        return 'Enter a phone number with country code.';
      default:
        return message == null || message.isEmpty
            ? 'Authentication failed ($code). Please try again.'
            : 'Authentication failed ($code): $message';
    }
  }

  String? _normalizePhoneNumber(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10 || digits.length > 15) return null;
      return '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length >= 11 && digits.length <= 15) return '+$digits';
    return null;
  }
}
