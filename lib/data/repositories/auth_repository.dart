import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser =
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();

    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  Future<ConfirmationResult> signInWithPhoneNumber(String phoneNumber) async {
    return await _auth.signInWithPhoneNumber(phoneNumber);
  }

  PhoneAuthCredential phoneCredential({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> createUserDocument(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toFirestore());
  }

  Future<UserModel?> getUserDocument(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<bool> checkUserExists(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists;
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    await _firestore.collection('users').doc(userId).update({
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Add a new role to existing user
  Future<void> addRoleToUser(String userId, UserRole newRole) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final existingRoles = data['roles'] != null
        ? List<String>.from(data['roles'])
        : [data['role'] as String];

    if (!existingRoles.contains(newRole.name)) {
      existingRoles.add(newRole.name);
    }

    await _firestore.collection('users').doc(userId).update({
      'roles': existingRoles,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Create sub-collection document for role-specific data
  Future<void> createRoleDocument(String userId, UserRole role, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(role.name) // 'customer' or 'employee'
        .doc('profile')
        .set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get role-specific sub-document
  Future<Map<String, dynamic>?> getRoleDocument(String userId, UserRole role) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection(role.name)
        .doc('profile')
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // Update role-specific sub-document
  Future<void> updateRoleDocument(String userId, UserRole role, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(role.name)
        .doc('profile')
        .set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Check if user has a specific role
  Future<bool> userHasRole(String userId, UserRole role) async {
    final doc = await getRoleDocument(userId, role);
    return doc != null;
  }

  Future<void> deleteUserDocument(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
