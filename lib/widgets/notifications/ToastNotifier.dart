import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ToastNotifier {
  const ToastNotifier._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);

    const Color cyanBrand = Color(0xFF00FFFF);
    const Color errorRed = Color(0xFFFF4D4D);
    final Color activeColor = isError ? errorRed : cyanBrand;

    final TextStyle messageStyle = GoogleFonts.plusJakartaSans(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      decoration: TextDecoration.none, // Explicitly removes any lines
    );

    showTopSnackBar(
      overlay,
      displayDuration: const Duration(milliseconds: 2500),
      // Wrap everything in Material to fix the yellow underline visual bug
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: activeColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.info_outline,
                    color: activeColor,
                    size: 24,
                  ).animate().shimmer(
                        duration: 2000.ms,
                        color: Colors.white,
                      ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      message,
                      style: messageStyle,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(
                begin: -0.5,
                end: 0,
                curve: Curves.easeOutExpo,
              )
              .scale(
                begin: const Offset(0.9, 0.9),
                duration: 400.ms,
              ),
        ),
      ),
    );
  }
}