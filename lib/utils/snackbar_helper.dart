import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../core/constants.dart';

class SnackBarHelper {
  static void showSuccessSnackBar(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      CupertinoIcons.check_mark_circled,
      AppColors.success,
    );
  }

  static void showInfoSnackBar(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      CupertinoIcons.info_circle,
      AppColors.info,
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      CupertinoIcons.exclamationmark_circle,
      AppColors.error,
    );
  }

  static void showWarningSnackBar(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      CupertinoIcons.exclamationmark_triangle,
      AppColors.warning,
    );
  }

  static void _showCustomSnackBar(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          height: 60,
          width: MediaQuery.sizeOf(context).width,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.textSecondary.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 12,
              ),
            ],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 3),
    );
  }
}
