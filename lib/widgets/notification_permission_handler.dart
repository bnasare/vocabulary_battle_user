import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import 'dialogs/notification_permission_dialog.dart';

/// Widget that handles showing the notification permission dialog once
class NotificationPermissionHandler extends StatefulWidget {
  final Widget child;

  const NotificationPermissionHandler({
    super.key,
    required this.child,
  });

  @override
  State<NotificationPermissionHandler> createState() =>
      _NotificationPermissionHandlerState();
}

class _NotificationPermissionHandlerState
    extends State<NotificationPermissionHandler> {
  bool _hasCheckedPermission = false;

  @override
  void initState() {
    super.initState();
    // Check and request permission after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermission();
    });
  }

  Future<void> _checkAndRequestPermission() async {
    // Only check once per widget lifetime
    if (_hasCheckedPermission) return;
    _hasCheckedPermission = true;

    final notificationService = NotificationService();

    // Check if we've already asked for permission
    final hasAsked = await notificationService.hasAskedForPermission();

    if (hasAsked) {
      // Already asked before, just check if enabled and initialize if needed
      final isEnabled = await notificationService.areNotificationsEnabled();
      if (isEnabled) {
        // initialize() has its own guard against re-initialization
        await notificationService.initialize();
      }
      return;
    }

    // First time - show explanation dialog
    if (!mounted) return;

    final shouldAsk = await NotificationPermissionDialog.show(context);

    if (shouldAsk) {
      // User agreed - request permission
      await notificationService.requestPermissionAndInitialize();
    } else {
      // User clicked "Not Now" - mark as asked so we don't show again
      await notificationService.markPermissionAsked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
