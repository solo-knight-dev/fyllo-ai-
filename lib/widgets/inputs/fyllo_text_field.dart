import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fyllo_ai/utils/app_constants.dart';

class FylloTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final IconData? prefixIcon;
  final bool enabled;

  final Widget? suffixIcon;
  final int? maxLength;

  const FylloTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.prefixIcon,
    this.enabled = true,
    this.suffixIcon,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    // FYLLO DESIGN SYSTEM COLORS
    const Color cyanBrand = FylloColors.defaultCyan; 
    const Color darkBg = FylloColors.darkGray;

    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        counterText: "", // Hide the character counter
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: cyanBrand)
                .animate()
                .scale(
                  delay: 200.ms, 
                  begin: const Offset(0.5, 0.5), 
                  end: const Offset(1.0, 1.0)
                )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: darkBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cyanBrand, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms, delay: 100.ms)
    .slideX(begin: -0.1, curve: Curves.easeOut);
  }
}