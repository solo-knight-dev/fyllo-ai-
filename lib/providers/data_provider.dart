
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyllo_ai/models/expense_model.dart';
import 'package:fyllo_ai/services/feedback_service.dart';

class DataProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Expense> _expenses = [];
  bool _isLoading = false;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  Future<void> fetchExpenses() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      _expenses = snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching expenses: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .add(expense.toMap());
      
      // Create a new expense with the generated ID
      final newExpense = expense.copyWith(id: docRef.id);
      
      _expenses.insert(0, newExpense);
      
      // Track scan milestone globally (await to ensure persistence before check)
      await FeedbackService.incrementScanCount();
      
      notifyListeners();
    } catch (e) {
      print("Error adding expense: $e");
      rethrow;
    }
  }
  Future<void> deleteExpense(String expenseId) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .doc(expenseId)
          .delete();
      
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e) {
      print("Error deleting expense: $e");
      rethrow;
    }
  }

  // Calculate total spending
  double get totalSpending {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Get recent transactions (last 5)
  List<Expense> get recentTransactions {
    return _expenses.take(5).toList();
  }

  // Get current month expenses count
  int get currentMonthExpensesCount {
    final now = DateTime.now();
    return _expenses.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;
    }).length;
  }
}
