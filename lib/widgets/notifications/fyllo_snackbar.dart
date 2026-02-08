import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../utils/app_constants.dart';

/// Custom Fyllo-branded snackbar
class FylloSnackBar extends StatelessWidget {
  final String message;
  final FylloSnackBarType type;
  final IconData? icon;

  const FylloSnackBar({
    super.key,
    required this.message,
    this.type = FylloSnackBarType.success,
    this.icon,
  });

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message, {IconData? icon}) {
    showTopSnackBar(
      Overlay.of(context),
      FylloSnackBar(
        message: message,
        type: FylloSnackBarType.success,
        icon: icon,
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

  /// Show error snackbar
  static void showError(BuildContext context, String message, {IconData? icon}) {
    showTopSnackBar(
      Overlay.of(context),
      FylloSnackBar(
        message: message,
        type: FylloSnackBarType.error,
        icon: icon,
      ),
      displayDuration: const Duration(seconds: 3),
    );
  }

  /// Show info snackbar
  static void showInfo(BuildContext context, String message, {IconData? icon}) {
    showTopSnackBar(
      Overlay.of(context),
      FylloSnackBar(
        message: message,
        type: FylloSnackBarType.info,
        icon: icon,
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

  /// Show warning snackbar
  static void showWarning(BuildContext context, String message, {IconData? icon}) {
    showTopSnackBar(
      Overlay.of(context),
      FylloSnackBar(
        message: message,
        type: FylloSnackBarType.warning,
        icon: icon,
      ),
      displayDuration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    // The Material widget is the fix for the yellow underline
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              config.backgroundColor,
              config.backgroundColor.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: config.borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: config.backgroundColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: config.iconBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon ?? config.defaultIcon,
                color: config.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Message
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: config.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  // decoration: TextDecoration.none is an extra safety layer
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _SnackBarConfig _getConfig() {
    switch (type) {
      case FylloSnackBarType.success:
        return _SnackBarConfig(
          backgroundColor: FylloColors.obsidian,
          borderColor: FylloColors.success,
          iconBackgroundColor: FylloColors.success.withOpacity(0.15),
          iconColor: FylloColors.success,
          textColor: Colors.white,
          defaultIcon: Icons.check_circle_rounded,
        );
      case FylloSnackBarType.error:
        return _SnackBarConfig(
          backgroundColor: FylloColors.obsidian,
          borderColor: FylloColors.error,
          iconBackgroundColor: FylloColors.error.withOpacity(0.15),
          iconColor: FylloColors.error,
          textColor: Colors.white,
          defaultIcon: Icons.error_rounded,
        );
      case FylloSnackBarType.info:
        return _SnackBarConfig(
          backgroundColor: FylloColors.obsidian,
          borderColor: FylloColors.info,
          iconBackgroundColor: FylloColors.info.withOpacity(0.15),
          iconColor: FylloColors.info,
          textColor: Colors.white,
          defaultIcon: Icons.info_rounded,
        );
      case FylloSnackBarType.warning:
        return _SnackBarConfig(
          backgroundColor: FylloColors.obsidian,
          borderColor: FylloColors.warning,
          iconBackgroundColor: FylloColors.warning.withOpacity(0.15),
          iconColor: FylloColors.warning,
          textColor: Colors.white,
          defaultIcon: Icons.warning_rounded,
        );
    }
  }
}

enum FylloSnackBarType {
  success,
  error,
  info,
  warning,
}

class _SnackBarConfig {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color textColor;
  final IconData defaultIcon;

  _SnackBarConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.defaultIcon,
  });
}