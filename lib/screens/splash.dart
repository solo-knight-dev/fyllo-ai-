import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/revenue_cat_service.dart';

import '../router/mainshell.dart';
import '../utils/app_constants.dart';
import 'AuthScreen.dart';
import 'setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _startAppFlow();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _startAppFlow() async {
    // Start auth check in background
    final user = FirebaseAuth.instance.currentUser;

    // Load subscription status in background if logged in
    if (user != null) {
      unawaited(RevenueCatService.setUserId(user.uid));
      unawaited(Provider.of<SubscriptionProvider>(context, listen: false).initialize());
    }

    // Wait for animations to complete - 3 seconds for optimal user experience
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        Widget nextScreen;
        if (doc.exists && doc.data()?.containsKey('jurisdiction') == true) {
          nextScreen = MainShell();
        } else {
          nextScreen = const SetupScreen();
        }

        _navigateWithFade(nextScreen);
      } catch (e) {
        debugPrint("Error fetching user data: $e");
        // Fallback to MainShell if there's an error but user is logged in
        _navigateWithFade(const MainShell());
      }
    } else {
      _navigateWithFade(const AuthScreen());
    }
  }

  void _navigateWithFade(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: 800.ms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: FylloColors.obsidian, // Charcoal/Black background
        ),
        child: Stack(
          children: [
            // Simplified ambient orbs for a cleaner look
            _buildGradientOrb(
              alignment: Alignment.center,
              color: FylloColors.defaultCyan,
              size: 400,
              delay: 0,
            ),

            // Removed Particle effect (snow) as per user request


            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Centered logo with refined glow
                  Container(
                    width: 160,
                    height: 160,
                    clipBehavior: Clip.antiAlias, // Ensures logo fits the circle
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FylloColors.defaultCyan.withOpacity(0.2), // Softer glow
                          blurRadius: 80,
                          spreadRadius: 0, // Removed the "frame" effect
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  )
                  .animate()
                  .fade(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    curve: Curves.easeOutBack,
                    duration: 1000.ms,
                  )
                  .then()
                  .shimmer(
                    duration: 2000.ms,
                    color: FylloColors.secondaryBlue,
                  ),

                  const SizedBox(height: 40),

                  // App name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        FylloColors.defaultCyan,
                        FylloColors.secondaryBlue,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      FylloApp.appName.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 48,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 800.ms)
                  .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 16),

                  // Tagline
                   Text(
                    FylloApp.tagline.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                      color: FylloColors.defaultCyan.withOpacity(0.8),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 1200.ms, duration: 800.ms)
                  .slideY(begin: 0.5, end: 0),

                  const SizedBox(height: 8),

                  // AI Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          FylloColors.defaultCyan.withOpacity(0.2),
                          FylloColors.secondaryBlue.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: FylloColors.defaultCyan.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: FylloColors.defaultCyan,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI POWERED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                            color: FylloColors.defaultCyan,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .scale(begin: const Offset(0.8, 0.8)),

                  const SizedBox(height: 48),

                  // Creative Loading Spinner (Neural Orbit)
                  _buildNeuralOrbitSpinner(),
                ],
              ),
            ),

            // Footer
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                   Text(
                    "ENGINEERED BY",
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      letterSpacing: 3,
                      color: Colors.white24,
                    ),
                  ).animate().fade(delay: 2000.ms),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo/fidus.png',
                        height: 18,
                        color: Colors.white.withOpacity(0.9),
                        errorBuilder: (c, o, s) => const Icon(
                          Icons.bolt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                       Text(
                        "fidus tech",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 2400.ms).slideY(begin: 0.3, end: 0),
                ],
              ),
            ),

            // Removed bottom bar loading indicator
          ],
        ),
      ),
    );
  }

  Widget _buildNeuralOrbitSpinner() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner Pulse
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: FylloColors.defaultCyan,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat()).scale(
              begin: const Offset(1, 1),
              end: const Offset(2.5, 2.5),
              duration: 1500.ms,
              curve: Curves.easeOut).fadeOut(),

          // Outer Orbit 1
          RotationTransition(
            turns: _particleController,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: FylloColors.defaultCyan,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Outer Orbit 2 (Reverse)
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_particleController.value * 2 * math.pi,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: FylloColors.secondaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Fixed Ring
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: FylloColors.defaultCyan.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 2000.ms);
  }

  Widget _buildGradientOrb({
    required Alignment alignment,
    required Color color,
    required double size,
    required int delay,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
      )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .fadeIn(delay: delay.ms)
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.2, 1.2),
        duration: 3000.ms,
      ),
    );
  }
}

