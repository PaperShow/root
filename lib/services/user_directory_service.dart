import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Public profile of an app user, stored at `users/{uid}` so others can find
/// them by username or email when adding group members or lending records.
class AppUserProfile {
  final String uid;
  final String displayName;
  final String? email;
  final String username;
  final String? photoUrl;

  const AppUserProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    this.email,
    this.photoUrl,
  });

  factory AppUserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return AppUserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? map['username'] as String? ?? 'User',
      email: map['email'] as String?,
      username: map['username'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
    );
  }
}

class UserDirectoryService {
  static final UserDirectoryService _instance = UserDirectoryService._internal();
  factory UserDirectoryService() => _instance;
  UserDirectoryService._internal();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static bool looksLikeEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  static String usernameFromEmail(String email) =>
      email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');

  /// Creates or refreshes the signed-in user's public profile.
  Future<AppUserProfile?> upsertCurrentUser(User user) async {
    final email = user.email?.toLowerCase();
    if (email == null) return null; // Only email accounts are discoverable
    final username = usernameFromEmail(email);
    final displayName = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : username;
    try {
      await _users.doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'username': username,
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('UserDirectoryService upsert error: $e');
    }
    return AppUserProfile(
      uid: user.uid,
      displayName: displayName,
      email: email,
      username: username,
      photoUrl: user.photoURL,
    );
  }

  /// Finds users by exact email, or by username / name prefix.
  Future<List<AppUserProfile>> search(String rawQuery, {String? excludeUid}) async {
    final query = rawQuery.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (query.length < 2) return [];

    final results = <String, AppUserProfile>{};
    void addAll(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        if (doc.id == excludeUid) continue;
        results[doc.id] = AppUserProfile.fromMap(doc.id, doc.data());
      }
    }

    try {
      if (looksLikeEmail(query)) {
        addAll(await _users.where('email', isEqualTo: query).limit(5).get());
      } else {
        final end = '$query';
        final snaps = await Future.wait([
          _users.where('username', isGreaterThanOrEqualTo: query).where('username', isLessThan: end).limit(8).get(),
          _users.where('displayNameLower', isGreaterThanOrEqualTo: query).where('displayNameLower', isLessThan: end).limit(8).get(),
        ]);
        snaps.forEach(addAll);
      }
    } catch (e) {
      debugPrint('UserDirectoryService search error: $e');
    }
    return results.values.toList();
  }
}
