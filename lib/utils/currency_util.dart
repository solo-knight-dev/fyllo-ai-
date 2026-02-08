import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CurrencyUtil {
  static String getCurrencySymbol(String? jurisdiction) {
    if (jurisdiction == null) return '\$';
    
    switch (jurisdiction.toUpperCase()) {
      case 'INDIA':
        return '₹';
      case 'UK':
        return '£';
      case 'IRELAND':
        return '€';
      case 'UAE':
        return 'د.إ '; // Exact symbol as requested
      case 'USA':
      case 'CANADA':
      case 'AUSTRALIA':
      case 'SINGAPORE':
        return '\$';
      default:
        return '\$';
    }
  }

  static NumberFormat getCurrencyFormat(String? jurisdiction) {
    final symbol = getCurrencySymbol(jurisdiction);
    // Use NumberFormat.currency and ensure the symbol is used correctly as a prefix
    return NumberFormat.currency(
      symbol: symbol, 
      decimalDigits: 2,
      customPattern: '\u00A4 #,##0.00', // \u00A4 is the currency symbol placeholder
    );
  }

  static Future<String> getUserJurisdiction() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'USA';

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('jurisdiction') ?? 'USA';
      }
    } catch (e) {
      print("Error fetching jurisdiction: $e");
    }
    return 'USA';
  }
}
