import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:fyllo_ai/models/expense_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanService {
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, dynamic>> processReceipt(File imageFile, String userId) async {
    try {
      // 1. OCR (On-Device, Free & Fast)
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      String rawText = recognizedText.text;

      // Check if no text was found
      if (rawText.isEmpty || rawText.trim().isEmpty) {
        throw Exception("NO_TEXT_FOUND");
      }
      
      // Check for very minimal text (likely blur or poor quality)
      if (rawText.length < 5) {
        throw Exception("NO_TEXT_FOUND");
      }

      // Check for blurry image using text block confidence
      // ML Kit doesn't provide confidence in all cases, so we check block count too
      bool likelyBlurry = false;
      if (recognizedText.blocks.isNotEmpty) {
        // If we have very few blocks despite having some text, likely blurry
        if (recognizedText.blocks.length < 2 && rawText.length < 20) {
          likelyBlurry = true;
        }
      }
      
      if (likelyBlurry) {
        throw Exception("IMAGE_TOO_BLURRY");
      }

      print("📄 OCR Text Length: ${rawText.length}");

      // 2. Call Secure Cloud Function
      final HttpsCallable callable = _functions.httpsCallable('analyzeReceipt');
      
      final result = await callable.call({
        'rawText': rawText,
      });

      print("🔍 Cloud Function Response Type: ${result.data.runtimeType}");
      print("🔍 Cloud Function Response: ${result.data}");

      // 3. Parse Result - FIXED: Handle both Map and List responses
      Map<String, dynamic> data;
      
      if (result.data is Map) {
        // Expected response: Direct Map
        data = Map<String, dynamic>.from(result.data as Map);
      } else if (result.data is List) {
        // Unexpected response: List (maybe your Cloud Function returns array?)
        print("⚠️ WARNING: Cloud Function returned List instead of Map");
        final list = result.data as List;
        
        if (list.isEmpty) {
          throw Exception("Cloud Function returned empty list");
        }
        
        // Try to use first element if it's a Map
        if (list.first is Map) {
          data = Map<String, dynamic>.from(list.first as Map);
        } else {
          throw Exception("Cloud Function returned unexpected format: ${list.first.runtimeType}");
        }
      } else {
        throw Exception("Cloud Function returned unexpected type: ${result.data.runtimeType}");
      }

      // Check for explicit error from backend
      if (data['error'] == 'no_receipt_found') {
        print("ℹ️ Backend reports no receipt found.");
        throw Exception("NO_TEXT_FOUND"); // Reuse existing mapping for "No receipt found" snackbar
      }

      // Validate required fields
      if (!data.containsKey('amount') || !data.containsKey('merchant')) {
        print("⚠️ Missing required fields. Data: $data");
        throw Exception("AI analysis incomplete. Please try again.");
      }

      data['rawText'] = rawText;
      
      print("✅ Parsed data successfully: ${data.keys}");
      return data;

    } catch (e) {
      print("❌ ScanService Error: $e");
      
      if (e is FirebaseFunctionsException) {
        print("Firebase Functions Error Code: ${e.code}");
        print("Firebase Functions Error Message: ${e.message}");
        print("Firebase Functions Error Details: ${e.details}");
        
        // User-friendly error messages
        if (e.code == 'unauthenticated') {
          throw Exception("Authentication failed. Please log in again.");
        } else if (e.code == 'resource-exhausted') {
          throw Exception("Out of AI credits. Please upgrade your plan.");
        } else if (e.code == 'invalid-argument') {
          throw Exception("Receipt image unclear. Please try again.");
        } else {
          throw Exception("AI analysis failed: ${e.message}");
        }
      }
      
      rethrow;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}