import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart' as auth;
import 'package:fyllo_ai/screens/profile_screen.dart';

class HeadNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const HeadNavBar({
    super.key,
    this.title = "FYLLO AI",
  });

  @override
  Widget build(BuildContext context) {
    // Brand color updated to match the logo (0xFF00D1FF)
    const Color cyanBrand = Color(0xFF00D1FF);
    final authProvider = Provider.of<auth.AuthProvider>(context); // Listen to changes
    final user = authProvider.user;

    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        children: [
          // Minimalist Logo Circle
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cyanBrand.withOpacity(0.5)),
            ),
            child: Image.asset(
              "assets/logo/logo.png",
              height: 28,
              errorBuilder: (c, o, s) =>
                  const Icon(Icons.code, color: Colors.white),
            ),
          ).animate().rotate(duration: 1.seconds),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),

      // Profile Button
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: GestureDetector(
            onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (context) => const ProfileScreen()),
               );
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cyanBrand.withOpacity(0.5), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 16, // Size
                backgroundColor: Colors.grey[800],
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
