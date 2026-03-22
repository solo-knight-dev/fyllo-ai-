import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/notifications/ToastNotifier.dart';

// NEW FYLLO SCREENS (You will create these)
import '../screens/dashboard_screen.dart';
import '../screens/vault_screen.dart';
import '../screens/intelligence_screen.dart';
import '../screens/ai_camera_overlay.dart'; // The "Lens"
import '../services/feedback_service.dart';

// WIDGETS
import '../widgets/navigations/bottom_nav_bar.dart';
import '../widgets/navigations/head_nav_bar.dart';
import '../utils/app_constants.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // The 3 Main Tabs
  final List<Widget> _screens = const [
    DashboardScreen(),
    VaultScreen(),
    IntelligenceScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: const HeadNavBar(title: "FYLLO AI"), // Use your Fyllo HeadNav
      
      // Floating Action Button for AI Camera
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: FylloColors.defaultCyan,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final uid = authProvider.user?.uid;
          
          if (uid == null) return;

          // Check terms via Firestore for cross-device consistency
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final bool hasAccepted = userDoc.data()?['termsAccepted'] == true;

          if (hasAccepted) {
            if (mounted) {
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const AICameraOverlay())
              );
              
              // After camera closes, check if we hit a milestone (Centralized Check)
              if (mounted && await FeedbackService.shouldShowPrompt()) {
                FeedbackService.showFeedbackDialog(context);
              }
            }
          } else {
            if (mounted) {
              ToastNotifier.show(
                context, 
                "Please accept the App Intelligence Protocol on the Dashboard to start scanning.",
                isError: true,
              );
            }
          }
        },
        child: const Icon(Icons.document_scanner_rounded, color: Colors.black, size: 30),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),

      body: Stack(
        children: List.generate(_screens.length, (i) {
          final isActive = i == _currentIndex;
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            left: isActive ? 0 : (i < _currentIndex ? -MediaQuery.of(context).size.width : MediaQuery.of(context).size.width),
            top: 0,
            bottom: 0,
            right: isActive ? 0 : (i < _currentIndex ? MediaQuery.of(context).size.width : -MediaQuery.of(context).size.width),
            child: _screens[i],
          );
        }),
      ),
      
      bottomNavigationBar: BottomNavBar( // Use your Fyllo BottomNav
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}