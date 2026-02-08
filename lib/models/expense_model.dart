
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String merchantName;
  final DateTime date;
  final String? summary;
  
  // AI Fields
  final String aiAnalysis;
  final String taxImpact; // e.g. "Tax Deductible", "Partial", "Personal"
  final String deductionType; // e.g. "Meals & Entertainment", "Office Supplies"

  Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.merchantName,
    required this.date,
    this.summary,
    this.aiAnalysis = "Pending analysis...",
    this.taxImpact = "Unknown",
    this.deductionType = "Uncategorized",
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'Uncategorized',
      merchantName: data['merchantName'] ?? 'Unknown',
      date: (data['date'] as Timestamp).toDate(),
      summary: data['summary'],
      aiAnalysis: data['aiAnalysis'] ?? data['auditorExplanation'] ?? "No analysis available.",
      taxImpact: data['taxImpact'] ?? "Unknown",
      deductionType: data['deductionType'] ?? "General",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'merchantName': merchantName,
      'date': date,
      'summary': summary,
      'aiAnalysis': aiAnalysis,
      'taxImpact': taxImpact,
      'deductionType': deductionType,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Expense copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? merchantName,
    DateTime? date,
    String? summary,
    String? aiAnalysis,
    String? taxImpact,
    String? deductionType,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      merchantName: merchantName ?? this.merchantName,
      date: date ?? this.date,
      summary: summary ?? this.summary,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      taxImpact: taxImpact ?? this.taxImpact,
      deductionType: deductionType ?? this.deductionType,
    );
  }
}
