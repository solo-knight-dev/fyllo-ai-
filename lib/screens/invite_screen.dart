import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String referralCode = authProvider.user?.uid ?? "LOGIN_REQUIRED";

    // Professional share message
    final String shareMessage = """
Take control of your finances with Fyllo AI 🧠

Join me on the smartest AI finance tracker. Use my referral code to get 20 bonus AI credits instantly!

🎁 Your Bonus Code: $referralCode

📲 Download Fyllo AI now:
https://play.google.com/store/apps/details?id=com.fidus.fyllo_ai
    """;

    return Scaffold(
      backgroundColor: FylloColors.obsidian,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FylloColors.defaultCyan.withOpacity(0.08),
              ),
            ),
          ).animate().fadeIn(duration: 2.seconds),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Hero Section with Glassmorphism
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FylloColors.defaultCyan.withOpacity(0.12),
                        FylloColors.secondaryBlue.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: FylloColors.defaultCyan,
                        size: 48,
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 20),
                      Text(
                        "Give 20, Get 20",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Share Fyllo AI with friends. When they join, you both receive 20 AI Credits.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 40),

                // How it works
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStep(Icons.share_outlined, "Share"),
                    _buildConnector(),
                    _buildStep(Icons.person_add_outlined, "Join"),
                    _buildConnector(),
                    _buildStep(Icons.account_balance_wallet_outlined, "Earn"),
                  ],
                ).animate(delay: 400.ms).fadeIn(),

                const SizedBox(height: 48),

                // Quest Milestones
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: FylloColors.darkGray,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "QUEST MILESTONES",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Icon(Icons.military_tech_rounded, color: FylloColors.defaultCyan, size: 20),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildMilestone("New Scout", "First referral", true),
                      _buildMilestoneSpacer(),
                      _buildMilestone("Credit Hunter", "3 referrals", false),
                      _buildMilestoneSpacer(),
                      _buildMilestone("Quest Champion", "10 referrals", false),
                    ],
                  ),
                ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 40),

                // Referral Code Box
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(
                        "YOUR UNIQUE QUEST KEY",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        _showCopyMessage(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: FylloColors.darkGray,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                referralCode,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: FylloColors.defaultCyan,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Icon(Icons.copy_rounded, color: FylloColors.defaultCyan.withOpacity(0.5), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.2),

                const SizedBox(height: 60),

                // Primary Share Action
                ElevatedButton(
                  onPressed: () => Share.share(shareMessage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FylloColors.defaultCyan,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                    shadowColor: FylloColors.defaultCyan.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "SEND QUEST INVITE",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 900.ms).fadeIn().scale(),

                const SizedBox(height: 24),

                Text(
                  "Credits are awarded automatically upon successful sign-up.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestone(String name, String requirement, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? FylloColors.defaultCyan.withOpacity(0.1) : Colors.white.withOpacity(0.02),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? FylloColors.defaultCyan : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : Icons.lock_outline_rounded,
            color: isCompleted ? FylloColors.defaultCyan : Colors.white24,
            size: 16,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                color: isCompleted ? Colors.white : Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              requirement,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white24,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMilestoneSpacer() {
    return Container(
      margin: const EdgeInsets.only(left: 15),
      height: 20,
      width: 2,
      color: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildStep(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: Colors.white60, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 20,
      height: 1,
      color: Colors.white10,
    );
  }

  void _showCopyMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text("Code copied to clipboard!", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: FylloColors.defaultCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}