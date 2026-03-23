import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import '../core/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize Google Sign-In if not already initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  /// Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Ensure Google Sign-In is initialized
      await _ensureInitialized();

      // Trigger the authentication flow (single prompt)
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Get or create user in Firestore
      final userModel = await _createOrUpdateUser(userCredential.user!);

      return userModel;
    } on GoogleSignInException catch (e) {
      // User canceled or error occurred
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Create or update user in Firestore
  Future<UserModel> _createOrUpdateUser(User firebaseUser) async {
    final userRef =
        _firestore.collection(FirestoreCollections.users).doc(firebaseUser.uid);

    final userDoc = await userRef.get();

    // Get FCM token
    final fcmToken = await _getFCMToken();

    if (!userDoc.exists) {
      // Create new user
      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'User',
        photoURL: firebaseUser.photoURL,
        isAdmin: true, // BOTH players are admins
        fcmToken: fcmToken,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        stats: UserStats(),
      );

      await userRef.set(newUser.toMap());
      return newUser;
    } else {
      // Update existing user
      await userRef.update({
        'lastLogin': Timestamp.fromDate(DateTime.now()),
        'fcmToken': fcmToken,
        if (firebaseUser.displayName != null)
          'displayName': firebaseUser.displayName,
        if (firebaseUser.photoURL != null) 'photoURL': firebaseUser.photoURL,
      });

      return UserModel.fromFirestore(userDoc);
    }
  }

  /// Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging.getToken();
        return token;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update FCM token
  Future<void> updateFCMToken() async {
    if (currentUserId == null) return;

    final token = await _getFCMToken();
    if (token != null) {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .update({'fcmToken': token});
    }
  }

  /// Get user model from Firestore
  Future<UserModel?> getUserModel(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    if (currentUserId == null) return null;
    return getUserModel(currentUserId!);
  }

  /// Stream of current user model
  Stream<UserModel?> getCurrentUserModelStream() {
    if (currentUserId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(FirestoreCollections.users)
        .doc(currentUserId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      // Note: We don't call terminate()/clearPersistence() here because:
      // 1. It can crash if there are ongoing Firestore operations (e.g., PresenceService)
      // 2. Provider invalidation + autoDispose ensures clean state
      // 3. Firestore cache will be naturally replaced when new user logs in
    } catch (e) {
      rethrow;
    }
  }

  /// Delete account (admin only)
  Future<void> deleteAccount() async {
    if (currentUserId == null) return;

    try {
      // Delete user document
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .delete();

      // Delete Firebase auth account
      await _auth.currentUser?.delete();
    } catch (e) {
      rethrow;
    }
  }
}
