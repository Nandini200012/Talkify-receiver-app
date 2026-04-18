import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  UserModel? _userModel;
  bool _isLoading = false;
  bool _isInitializing = true;

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;

  AuthProvider() {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await fetchUserData(user.uid);
      await updatePresence(true);
      FlutterBackgroundService().startService();
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> updatePresence(bool isOnline) async {
    if (_auth.currentUser != null) {
      try {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'isOnline': isOnline,
        });
        if (_userModel != null) {
          _userModel = UserModel(
            uid: _userModel!.uid,
            name: _userModel!.name,
            email: _userModel!.email,
            profilePic: _userModel!.profilePic,
            fcmToken: _userModel!.fcmToken,
            isOnline: isOnline,
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error updating presence: $e');
      }
    }
  }

  Future<void> fetchUserData(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        // Update FCM token
        String? token = await _fcm.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(uid).update({'fcmToken': token});
        }
        
        // Listen for token refreshes
        _fcm.onTokenRefresh.listen((newToken) {
          _firestore.collection('users').doc(uid).update({'fcmToken': newToken});
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await fetchUserData(credential.user!.uid);
      await updatePresence(true);
      FlutterBackgroundService().startService();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? token = await _fcm.getToken();

      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
        profilePic: '',
        fcmToken: token ?? '',
        isOnline: true,
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      
      // Sign out immediately so registration doesn't lead to direct login
      await logout();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await updatePresence(false);
    FlutterBackgroundService().invoke('stopService');
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }
}
