import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/data_provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart'; // Needed for Auth
import 'package:fyllo_ai/providers/subscription_provider.dart'; // Added for Plan Badge
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyllo_ai/screens/billing_screen.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:fyllo_ai/utils/currency_util.dart';
// Removed InviteScreen import

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchExpenses();
      // REMOVED: Automatic terms popup
      // _checkTermsAndConditions(); 
    });
  }

  Future<void> _checkTermsAndConditions() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasAccepted = prefs.getBool('accepted_terms_v2') ?? false; // Bumped version for new logic

    if (!hasAccepted && mounted) {
      _showTermsDialog(prefs);
    }
  }

  void _showTermsDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: FylloColors.defaultCyan, width: 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: FylloColors.defaultCyan, size: 48), // Shield Icon
                  const SizedBox(height: 16),
                  Text(
                    "App Intelligence Protocol",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Fyllo AI provides smart finance tracking and intelligent insight capabilities. By proceeding, you engage our AI algorithms to analyze your data and provide financial optimization strategies.\n\nNote: While our systems operate with high precision, Fyllo AI acts as a strategic technical assistant, not a licensed finance advisor. Final verification of financial data remains with your authorized professionals.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FylloColors.defaultCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 10,
                        shadowColor: FylloColors.defaultCyan.withOpacity(0.5),
                      ),
                      onPressed: () async {
                        // 1. Local Save
                        await prefs.setBool('accepted_terms_v2', true);
                        
                        // 2. Cloud Save (Legal Proof)
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final uid = authProvider.user?.uid;
                        if (uid != null) {
                            try {
                                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                    'termsAccepted': true,
                                    'termsAcceptedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                            } catch (e) {
                                print("Error saving T&C: $e");
                                // Proceed anyway so user isn't stuck
                            }
                        }

                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(
                        "ACKNOWLEDGE & PROCEED",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context); // Listen to plan changes

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(authProvider.user?.uid).snapshots(),
      builder: (context, snapshot) {
        // Show loading while waiting for Firestore data to prevent UI flash
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: FylloColors.defaultCyan));
        }

        String jurisdiction = 'USA';
        String plan = subscriptionProvider.currentPlan; 

        if (snapshot.hasData && snapshot.data!.exists) {
          jurisdiction = snapshot.data!.get('jurisdiction') ?? 'USA';
        }
        
        final currencyFormat = CurrencyUtil.getCurrencyFormat(jurisdiction);
        final userData = (snapshot.hasData && snapshot.data!.exists) 
            ? snapshot.data!.data() as Map<String, dynamic>? 
            : null;
        final bool termsAccepted = userData?['termsAccepted'] == true;

        return dataProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: FylloColors.defaultCyan))
            : RefreshIndicator(
                onRefresh: () => dataProvider.fetchExpenses(),
                color: FylloColors.defaultCyan,
                backgroundColor: FylloColors.darkGray,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Plan Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Finance Dashboard",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                // Terms Button
                                IconButton(
                                  onPressed: () async {
                                    final prefs = await SharedPreferences.getInstance();
                                    _showTermsDialog(prefs);
                                  },
                                  icon: Icon(
                                    termsAccepted ? Icons.check_circle : Icons.info_outline, 
                                    color: termsAccepted ? Colors.greenAccent : Colors.white54, 
                                    size: 20
                                  ),
                                  tooltip: termsAccepted ? "Terms Accepted" : "Review Terms",
                                ),
                                const SizedBox(width: 8),
                                // Plan Badge - Tappable
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const BillingScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: plan == 'elite'
                                          ? LinearGradient(
                                              colors: [FylloColors.defaultCyan, FylloColors.secondaryBlue],
                                            )
                                          : null,
                                      color: plan == 'elite' ? null : (plan == 'pro' ? FylloColors.defaultCyan.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: plan == 'free' ? Colors.white.withOpacity(0.3) : FylloColors.defaultCyan,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          plan == 'elite' ? Icons.workspace_premium : (plan == 'pro' ? Icons.star : Icons.person),
                                          color: plan == 'elite' ? Colors.black : FylloColors.defaultCyan,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          plan.toUpperCase(),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: plan == 'elite' ? Colors.black : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Total Spending / Optimization Potential Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: FylloColors.darkGray,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: FylloColors.defaultCyan.withOpacity(0.05),
                                blurRadius: 30,
                                spreadRadius: -5,
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TOTAL EXPENSES SCANNED", 
                                style: TextStyle(color: Colors.white54, letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(currencyFormat.format(dataProvider.totalSpending), 
                                style: GoogleFonts.plusJakartaSans(color: FylloColors.defaultCyan, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Optimization Potential: ${currencyFormat.format(dataProvider.totalSpending * 0.3)}", // Mock calculation
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        Text(
                          "Recent Activity",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        dataProvider.recentTransactions.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Text("No transactions yet.\nScan a receipt to get started.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white.withOpacity(0.3), height: 1.5)),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: dataProvider.recentTransactions.length,
                                itemBuilder: (context, index) {
                                  final expense = dataProvider.recentTransactions[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: FylloColors.darkGray,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: FylloColors.mediumGray,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.receipt_long_rounded, color: FylloColors.defaultCyan, size: 22),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(expense.merchantName,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 2),
                                              Text(DateFormat.yMMMd().format(expense.date),
                                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Text(currencyFormat.format(expense.amount),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              );
      },
    );
  }
}
