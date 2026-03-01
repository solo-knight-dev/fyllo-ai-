import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fyllo_ai/utils/app_constants.dart';

class FylloButton extends StatelessWidget {
  final String label;
  final Future<void> Function()? onPressed;
  final bool isDisabled;
  final bool isLoading;
  final Widget? icon;
  final Color? color; 

  const FylloButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isDisabled = false,
    this.isLoading = false,
    this.icon,
    this.color, 
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = isDisabled || isLoading || onPressed == null;
    
    // Fyllo Brand Colors
    const Color defaultCyan = FylloColors.defaultCyan;
    const Color secondaryBlue = FylloColors.secondaryBlue;

    // FIXED: Text is now pure white for high contrast, white38 when disabled
    final Color contentColor = disabled ? Colors.white38 : Colors.white;

    Widget buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null && !isLoading) ...[
          icon!,
          const SizedBox(width: 10),
        ],
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans( 
            color: contentColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: disabled 
            ? null 
            : LinearGradient(
                colors: color != null 
                    ? [color!, color!.withOpacity(0.8)] 
                    : [defaultCyan, secondaryBlue],
              ),
        color: disabled ? Colors.white10 : null,
        boxShadow: disabled ? null : [
          BoxShadow(
            color: (color ?? defaultCyan).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (isLoading)
              Shimmer.fromColors(
                baseColor: Colors.white.withOpacity(0.1),
                highlightColor: Colors.white.withOpacity(0.3),
                child: Container(color: Colors.white),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: contentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: disabled ? null : () async => await onPressed?.call(),
              child: Center(
                // FIXED: Shows the spinner loader when isLoading is true
                child: isLoading ? _buildLoader(contentColor) : buttonContent,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
          begin: 0.2,
          end: 0,
          curve: Curves.easeOutQuart, 
        );
  }

  Widget _buildLoader(Color loaderColor) {
    return SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(
        color: loaderColor,
        strokeWidth: 3,
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms);
  }
}