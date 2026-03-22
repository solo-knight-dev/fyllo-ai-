
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/data_provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:fyllo_ai/utils/currency_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IntelligenceScreen extends StatelessWidget {
  const IntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(authProvider.user?.uid).snapshots(),
      builder: (context, snapshot) {
        String jurisdiction = 'USA';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          jurisdiction = data?['jurisdiction'] ?? 'USA';
        }
        final currencyFormat = CurrencyUtil.getCurrencyFormat(jurisdiction);

        // Generate basic insights locally
        final expenses = dataProvider.expenses;
        final totalSpent = dataProvider.totalSpending;
        
        // 1. Top Merchant
        Map<String, double> merchantSpending = {};
        for (var e in expenses) {
          merchantSpending[e.merchantName] = (merchantSpending[e.merchantName] ?? 0) + e.amount;
        }
        String topMerchant = merchantSpending.isEmpty ? "None" : 
          merchantSpending.entries.reduce((a, b) => a.value > b.value ? a : b).key;

        // 2. Average Transaction
        double avgTransaction = expenses.isEmpty ? 0 : totalSpent / expenses.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20), // Removed top padding as it's below AppBar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "AI Intelligence",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text("Real-time financial analysis", 
                style: TextStyle(color: Colors.white54)),
              
              const SizedBox(height: 30),

              // Main Insight Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FylloColors.defaultCyan.withOpacity(0.1), FylloColors.darkGray],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: FylloColors.defaultCyan),
                        const SizedBox(width: 10),
                        Text("KEY INSIGHT", 
                          style: GoogleFonts.plusJakartaSans(color: FylloColors.defaultCyan, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your spending is concentrated on $topMerchant this month."
                      " Consider diversifying vendors to reduce risk.",
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stat Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard("Top Spender", topMerchant, Icons.store),
                  _buildStatCard("Avg. Ticket", currencyFormat.format(avgTransaction), Icons.receipt),
                  _buildStatCard("Deductions", currencyFormat.format(totalSpent * 0.3), Icons.verified_user), // Mock
                  _buildStatCard("Risk Score", "Low", Icons.security),
                ],
              ),
              const SizedBox(height: 100), // Extra space for FAB and bottom nav
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FylloColors.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const Spacer(),
          Text(value, 
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(title, 
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}