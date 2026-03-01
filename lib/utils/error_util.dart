import 'package:flutter/material.dart';

class ErrorUtil {
  /// Converts complex/technical errors into friendly, Fyllo-branded messages.
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return "Something went wrong. Please try again.";

    final String errorStr = error.toString().toLowerCase();

    // 1. Scanning & AI Errors
    if (errorStr.contains('json') || errorStr.contains('format') || errorStr.contains('unexpected character')) {
      return "The AI engine had trouble reading this receipt. Please ensure it's flat and well-lit.";
    }
    if (errorStr.contains('credits') || errorStr.contains('exhausted') || errorStr.contains('limit reached')) {
      return "You've reached your AI analysis limit. Please upgrade your plan in the Billing section.";
    }
    if (errorStr.contains('no_text_found') || errorStr.contains('no text')) {
      return "No clear text found. Please move closer to the receipt.";
    }
    if (errorStr.contains('image_too_blurry') || errorStr.contains('blurry')) {
      return "The image is a bit blurry. Hold steady and try again.";
    }

    // 2. Connectivity Errors
    if (errorStr.contains('network') || errorStr.contains('socket') || errorStr.contains('connection') || errorStr.contains('host')) {
      return "Network connection issue. Please check your internet and try again.";
    }
    if (errorStr.contains('timeout')) {
      return "The request timed out. Our servers are a bit busy, please try in a moment.";
    }

    // 3. Permission & Auth Errors
    if (errorStr.contains('permission-denied') || errorStr.contains('insufficient-permission')) {
      return "Access denied. Please ensure you've accepted the App Terms on the Dashboard.";
    }
    if (errorStr.contains('auth') || errorStr.contains('user-not-found') || errorStr.contains('wrong-password')) {
      return "Authentication issue. Please sign in again to continue.";
    }
    if (errorStr.contains('camera_permission') || errorStr.contains('camera')) {
      return "Camera access is required to scan receipts. Please enable it in system settings.";
    }

    // 4. Default Fallback
    debugPrint("MASKED_TECHNICAL_ERROR: $errorStr"); // Log for developer eyes only
    return "Something went wrong. Our team has been notified. Please try again soon.";
  }
}
