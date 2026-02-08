import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:fyllo_ai/services/feedback_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FeedbackDialog extends StatelessWidget {
  const FeedbackDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: FylloColors.defaultCyan.withOpacity(0.05),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FylloColors.defaultCyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: FylloColors.defaultCyan,
                size: 40,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  duration: 1.seconds,
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                ),
            
            const SizedBox(height: 24),
            
            Text(
              "Enjoying Fyllo AI?",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              "You've completed 3 scans! Your feedback helps us build the smartest AI finance tracker. Would you mind rating us?",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await FeedbackService.triggerSystemRating(context);
                  await FeedbackService.setNeverShowAgain(); // Don't ask again if they rated
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FylloColors.defaultCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  "RATE US NOW 😍",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await FeedbackService.resetShownFlag();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Maybe Later",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await FeedbackService.setNeverShowAgain();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white30,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Never Show",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }
}
