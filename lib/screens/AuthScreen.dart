import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fyllo_ai/utils/app_constants.dart';

import '../providers/auth_provider.dart';
import '../widgets/inputs/fyllo_text_field.dart';
import '../widgets/buttons/fyllo_button.dart';
import '../widgets/notifications/ToastNotifier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../router/mainshell.dart';
import 'setup_screen.dart';
import 'package:fyllo_ai/utils/error_util.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _isPasswordVisible = false;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final referralController = TextEditingController();

  void toggleView() {
    setState(() => isLogin = !isLogin);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    const Color cyanBrand = FylloColors.defaultCyan;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyanBrand.withOpacity(0.05),
              ),
            ).animate().fadeIn(duration: 2.seconds).scale(),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cyanBrand.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 700.ms),

                      Image.asset(
                        "assets/logo/logo.png",
                        width: 70,
                        height: 70,
                      ).animate().scale(
                        delay: 150.ms,
                        curve: Curves.easeOutBack,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text(
                    isLogin ? "Welcome Back" : "Create Profile",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                      .animate(key: ValueKey<bool>(isLogin))
                      .fadeIn()
                      .slideY(begin: 0.1),

                  const SizedBox(height: 4),

                  Text(
                    isLogin ? "Log in to Fyllo AI" : "Join the smart finance era",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Name (Signup only)
                  if (!isLogin) ...[
                    FylloTextField(
                      controller: nameController,
                      hint: "Full Name",
                      prefixIcon: Icons.person_outline,
                    ).animate().fadeIn().slideX(),
                    const SizedBox(height: 10),
                  ],

                  // Email
                  FylloTextField(
                    controller: emailController,
                    hint: "Email Address",
                    prefixIcon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 10),

                  // Password
                  FylloTextField(
                    controller: passwordController,
                    hint: "Password",
                    obscure: !_isPasswordVisible,
                    maxLength: 30,
                    prefixIcon: Icons.fingerprint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: cyanBrand,
                      ),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),

                  // Referral (Signup only)
                  if (!isLogin) ...[
                    const SizedBox(height: 10),
                    FylloTextField(
                      controller: referralController,
                      hint: "Bonus Code (Optional)",
                      prefixIcon: Icons.card_giftcard,
                    ).animate().fadeIn().slideX(),
                  ],

                  const SizedBox(height: 20),

                  // Primary Button
                  FylloButton(
                    label: isLogin ? "Sign In" : "Create Account",
                    color: cyanBrand,
                    isLoading: auth.isLoading,
                    onPressed: () => _handleAuth(auth),
                  ),

                  const SizedBox(height: 14),

                  // Google Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      bool success = await auth.googleLogin(
                        referralCode: referralController.text.trim(),
                      );

                      if (success && mounted) {
                        ToastNotifier.show(
                          context,
                          "Identity Verified via Google",
                          isError: false,
                        );

                        final uid = auth.user?.uid;
                        if (uid != null) {
                          final doc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get();

                          if (mounted &&
                              doc.exists &&
                              doc.data()?.containsKey('jurisdiction') ==
                                  true) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MainShell()),
                            );
                            return;
                          }
                        }

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SetupScreen()),
                          );
                        }
                      } else if (!success && mounted) {
                        ToastNotifier.show(
                          context,
                          "Google Authentication Cancelled",
                          isError: true,
                        );
                      }
                    },
                    icon: Image.asset(
                      "assets/images/google.png",
                      height: 16,
                      errorBuilder: (c, o, s) =>
                          const Icon(Icons.g_mobiledata,
                              color: Colors.white),
                    ),
                    label: const Text(
                      "Continue with Google",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size(double.infinity, 46),
                      side: const BorderSide(color: Colors.white10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Toggle
                  TextButton(
                    onPressed: toggleView,
                    child: RichText(
                      text: TextSpan(
                        text: isLogin
                            ? "New to Fyllo AI? "
                            : "Already have an account? ",
                        style:
                            const TextStyle(color: Colors.white60),
                        children: [
                          TextSpan(
                            text: isLogin
                                ? "Get Access"
                                : "Sign In",
                            style: const TextStyle(
                              color: cyanBrand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuth(AuthProvider auth) async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ToastNotifier.show(
        context,
        "Credentials cannot be empty",
        isError: true,
      );
      return;
    }

    try {
      if (isLogin) {
        await auth.emailLogin(
          emailController.text,
          passwordController.text,
        );
        if (mounted) {
          ToastNotifier.show(
            context,
            "Access Granted",
            isError: false,
          );
        }
      } else {
        if (nameController.text.isEmpty) {
          ToastNotifier.show(
            context,
            "Name is required",
            isError: true,
          );
          return;
        }

        await auth.emailSignup(
          emailController.text,
          passwordController.text,
          nameController.text,
          referralCode: referralController.text.trim(),
        );

        if (mounted) {
          ToastNotifier.show(
            context,
            "Profile Synchronized",
            isError: false,
          );
        }
      }

      if (mounted) {
        final uid = auth.user?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (mounted &&
              doc.exists &&
              doc.data()?.containsKey('jurisdiction') ==
                  true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => MainShell()),
            );
            return;
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const SetupScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastNotifier.show(
          context,
          ErrorUtil.getFriendlyMessage(e),
          isError: true,
        );
      }
    }
  }
}
