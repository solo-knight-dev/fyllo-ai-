import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter/material.dart';
import 'package:fyllo_ai/widgets/cards/feedback_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fyllo_ai/widgets/notifications/ToastNotifier.dart';

class FeedbackService {
  static const String _scanCountKey = 'total_successful_scans';
  static const String _neverShowKey = 'never_show_rating';
  static const int _targetMilestone = 3; // Milestone: 3 scans

  static const String _promptShownKey = 'feedback_prompt_shown';

  /// Increment scan count independently
  static Future<void> incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(_scanCountKey) ?? 0;
    await prefs.setInt(_scanCountKey, currentCount + 1);
  }

  /// Check if we should show the prompt (at milestone and not already shown/opted out)
  static Future<bool> shouldShowPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool neverShow = prefs.getBool(_neverShowKey) ?? false;
      final bool alreadyShown = prefs.getBool(_promptShownKey) ?? false;
      final int currentCount = prefs.getInt(_scanCountKey) ?? 0;
      
      // Logic: At milestone, haven't permanently opted out, and haven't shown this session/milestone
      if (!neverShow && !alreadyShown && currentCount >= _targetMilestone) {
        // Mark as shown so it doesn't repeat after every scan
        await prefs.setBool(_promptShownKey, true);
        return true;
      }
    } catch (_) {
      // Silently fail to avoid interrupting the main user flow with technical errors
    }
    return false;
  }

  /// Clear the session flag so the prompt can show again (e.g. after Maybe Later)
  static Future<void> resetShownFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownKey, false);
  }

  /// Reset counter (optional)
  static Future<void> resetCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scanCountKey, 0);
  }

  /// Mark to never show again
  static Future<void> setNeverShowAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_neverShowKey, true);
  }

  static void showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FeedbackDialog(),
    );
  }

  /// Triggers the official system rating popup with a store fallback
  static Future<void> triggerSystemRating(BuildContext context) async {
    final InAppReview inAppReview = InAppReview.instance;
    
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        ToastNotifier.show(context, "Opening Store page...", isError: false);
        await _launchStore();
      }
    } catch (e) {
      // Use ErrorUtil to mask technical redirect issues
      ToastNotifier.show(
        context, 
        "Opening Store page...", // Friendly fallback message
        isError: false
      );
      await _launchStore();
    }
  }

  /// Direct fallback to Play Store via URL
  static Future<void> _launchStore() async {
    final Uri url = Uri.parse("https://play.google.com/store/apps/details?id=com.fidus.fyllo_ai");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // If Play Store link fails, try general market link
        final Uri marketUri = Uri.parse("market://details?id=com.fidus.fyllo_ai");
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("Store Launch Error: $e");
    }
  }
}
