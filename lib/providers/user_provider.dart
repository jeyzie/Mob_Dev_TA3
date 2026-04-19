import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider extends ChangeNotifier {
  String _avatarPath = '';
  String _displayName = '';

  String get avatarPath => _avatarPath;
  String get displayName => _displayName;

  /// Load user data from Firestore (only call after user is authenticated)
  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      _avatarPath = doc.data()?['avatarPath'] ?? '';
      _displayName = doc.data()?['displayName'] ?? user.email!.split('@').first;
    } else {
      _avatarPath = '';
      _displayName = user.email!.split('@').first;
    }
    notifyListeners();
  }

  /// Update the provider locally (after a Firestore update)
  void updateUser({String? avatarPath, String? displayName}) {
    if (avatarPath != null) _avatarPath = avatarPath;
    if (displayName != null) _displayName = displayName;
    notifyListeners();
  }
}