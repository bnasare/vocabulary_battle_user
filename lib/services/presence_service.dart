import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _presenceTimer;
  String? _currentUserId;

  /// Initialize presence tracking for a user
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await setOnline(true);
    _startPresenceUpdates();
  }

  /// Start periodic presence updates
  void _startPresenceUpdates() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      updateLastSeen();
    });
  }

  /// Set user online status
  Future<void> setOnline(bool isOnline) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently ignore errors
    }
  }

  /// Update last seen timestamp
  Future<void> updateLastSeen() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently ignore errors
    }
  }

  /// Dispose presence service and reset state
  /// This should be called when a user logs out to prevent
  /// tracking the wrong user when a new user logs in
  void dispose() {
    _presenceTimer?.cancel();
    if (_currentUserId != null) {
      setOnline(false);
      _currentUserId = null; // Reset user ID for clean state
    }
  }
}

/// Widget to manage presence based on app lifecycle
class PresenceManager extends StatefulWidget {
  final Widget child;
  final String userId;

  const PresenceManager({
    super.key,
    required this.child,
    required this.userId,
  });

  @override
  State<PresenceManager> createState() => _PresenceManagerState();
}

class _PresenceManagerState extends State<PresenceManager>
    with WidgetsBindingObserver {
  final _presenceService = PresenceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _presenceService.initialize(widget.userId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        _presenceService.setOnline(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background or closing
        _presenceService.setOnline(false);
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
