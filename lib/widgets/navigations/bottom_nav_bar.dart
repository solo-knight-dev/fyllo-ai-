import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_constants.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color cyanBrand = Color(0xFF00FFFF);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D), // Deep Obsidian
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent, // Let container handle color
        selectedItemColor: FylloColors.defaultCyan,
        unselectedItemColor: Colors.white24,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon(
              isActive: currentIndex == 0,
              icon: CupertinoIcons.layers_alt_fill, // Dashboard/Stack
              inactiveIcon: CupertinoIcons.layers_alt,
            ),
            label: "Overview",
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(
              isActive: currentIndex == 1,
              icon: CupertinoIcons.shield_fill, // Vault/Security
              inactiveIcon: CupertinoIcons.shield,
            ),
            label: "Vault",
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(
              isActive: currentIndex == 2,
              icon: CupertinoIcons.graph_square_fill, // Intelligence/Charts
              inactiveIcon: CupertinoIcons.graph_square,
            ),
            label: "Insights",
          ),
        ],
      ),
    );
  }

  Widget _buildIcon({
    required bool isActive,
    required IconData icon,
    required IconData inactiveIcon,
  }) {
    const inactiveColor = Colors.white24;

    final baseIcon = Icon(
      isActive ? icon : inactiveIcon,
      size: 28,
      color: isActive ? FylloColors.defaultCyan : inactiveColor,
    );

    if (!isActive) return baseIcon;

    // Fyllo "Pulse" Animation
    return baseIcon
        .animate()
        .scale(duration: 200.ms, end: const Offset(1.1, 1.1), curve: Curves.easeOut)
        .then()
        .shimmer(duration: 800.ms, color: Colors.white54)
        // FIX: .boxShadow extension requires 'end' parameter for the shadow definition
        // it does not accept blur/blurRadius directly as named args in this version.
        .boxShadow(
          end: BoxShadow(
            blurRadius: 15,
            color: FylloColors.defaultCyan.withOpacity(0.2),
          ),
        );
  }
}