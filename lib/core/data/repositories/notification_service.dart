import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification payloads are displayed by Android. Data is persisted by the backend.
}

class NotificationService {
  NotificationService(this._firestore, this._messaging);

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _refreshSubscription;
  String? _uid;
  String? _token;

  Future<void> initializeForUser(String uid) async {
    if (kIsWeb || _uid == uid) return;
    if (_uid != null && _token != null) {
      await _retireToken(_uid!, _token!);
      _token = null;
    }
    _uid = uid;
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);
    await _refreshSubscription?.cancel();
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => _saveToken(uid, token),
    );
  }

  Future<void> _saveToken(String uid, String token) async {
    if (_token != null && _token != token) {
      try {
        await _deleteToken(uid, _token!);
      } catch (_) {
        // A refreshed FCM token is already invalid; stale records are also
        // removed by the backend after a failed send.
      }
    }
    final tokenId = _tokenId(token);
    await _firestore
        .collection('device_tokens')
        .doc(uid)
        .collection('tokens')
        .doc(tokenId)
        .set(<String, dynamic>{
          'token': token,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    _token = token;
  }

  String _tokenId(String token) {
    final normalized = token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return normalized.length <= 24 ? normalized : normalized.substring(0, 24);
  }

  Future<void> _deleteToken(String uid, String token) => _firestore
      .collection('device_tokens')
      .doc(uid)
      .collection('tokens')
      .doc(_tokenId(token))
      .delete();

  Future<void> _retireToken(String uid, String token) async {
    try {
      await _deleteToken(uid, token);
    } catch (_) {
      // Continue so the local FCM registration can still be invalidated.
    }
    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Offline sign-out still clears local account state.
    }
  }

  Future<void> clearForUser() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    if (!kIsWeb && uid != null && token != null) {
      await _retireToken(uid, token);
    }
  }

  Future<void> dispose() async {
    await clearForUser();
  }
}
