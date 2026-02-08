import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../router/mainshell.dart';
import '../utils/app_constants.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isSaving = false;

  Future<void> _selectJurisdiction(String country, String taxBody, String currency) async {
    setState(() => _isSaving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'jurisdiction': country,
          'taxBody': taxBody,
          'currency': currency,
          'setupCompletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        
        // Final "Success" animation transition
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      // Handle error (e.g., show a toast)
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color cyanBrand = FylloColors.defaultCyan;
    const Color obsidian = FylloColors.obsidian;

    return Scaffold(
      backgroundColor: obsidian,
      body: Stack(
        children: [
          // Background subtle neural grid or glow
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyanBrand.withOpacity(0.03),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 3.seconds),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  // Progress indicator (Step 1 of 1)
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cyanBrand,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [BoxShadow(color: cyanBrand.withOpacity(0.5), blurRadius: 10)],
                    ),
                  ).animate().fadeIn().slideX(begin: -1),

                  const SizedBox(height: 20),

                  Text(
                    "CALIBRATE\nAI ENGINE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  Text(
                    "Select your business jurisdiction to activate localized smart finance insights.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 40),

                  // THE BIG THREE OPTIONS
                  Expanded(
                    child: _isSaving 
                      ? Center(child: CircularProgressIndicator(color: cyanBrand))
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildMarketTile(
                              title: "United States",
                              subtitle: "IRS & Federal Finance Logic",
                              flag: "🇺🇸",
                              countryCode: "USA",
                              taxBody: "IRS",
                              currency: "\$",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "United Kingdom",
                              subtitle: "HMRC & UK Finance Insights",
                              flag: "🇬🇧",
                              countryCode: "UK",
                              taxBody: "HMRC",
                              currency: "£",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "Canada",
                              subtitle: "CRA & Canada Smart Tracking",
                              flag: "🇨🇦",
                              countryCode: "CANADA",
                              taxBody: "CRA",
                              currency: "\$",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "Australia",
                              subtitle: "ATO & Australia Tax Logic",
                              flag: "🇦🇺",
                              countryCode: "AUSTRALIA",
                              taxBody: "ATO",
                              currency: "\$",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "India",
                              subtitle: "Income Tax & Digital Rupee Insights",
                              flag: "🇮🇳",
                              countryCode: "INDIA",
                              taxBody: "Income Tax Dept",
                              currency: "₹",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "Singapore",
                              subtitle: "IRAS & Asia-Pacific Finance Hub",
                              flag: "🇸🇬",
                              countryCode: "SINGAPORE",
                              taxBody: "IRAS",
                              currency: "\$",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "United Arab Emirates",
                              subtitle: "FTA & UAE Smart Audit",
                              flag: "🇦🇪",
                              countryCode: "UAE",
                              taxBody: "FTA",
                              currency: "د.إ",
                              color: FylloColors.defaultCyan,
                            ),
                            _buildMarketTile(
                              title: "Ireland",
                              subtitle: "Revenue & EU Finance Logic",
                              flag: "🇮🇪",
                              countryCode: "IRELAND",
                              taxBody: "Revenue",
                              currency: "€",
                              color: FylloColors.defaultCyan,
                            ),
                          ],
                        ),
                  ),

                  const SizedBox(height: 20),
                  
                  Center(
                    child: Text(
                      "Don't see your country? Global support coming soon.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTile({
    required String title,
    required String subtitle,
    required String flag,
    required String countryCode,
    required String taxBody,
    required String currency,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _selectJurisdiction(countryCode, taxBody, currency),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FylloColors.darkGray,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
    );
  }
}