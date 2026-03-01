import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart';
import 'package:fyllo_ai/services/revenue_cat_service.dart';
import 'package:fyllo_ai/widgets/notifications/fyllo_snackbar.dart';
import 'package:fyllo_ai/providers/subscription_provider.dart';
import 'package:fyllo_ai/utils/app_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedWorkType;
  String? _savedWorkType;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    // Access auth provider
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Brand colors from HeadNavBar ref
    const Color bgDark = Color(0xFF0D0D0D);
    const Color cyanBrand = Color(0xFF00D1FF);

    if (user == null) {
      return const Scaffold(
        backgroundColor: bgDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          "Profile",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Profile Photo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cyanBrand, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: cyanBrand.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Name
              Text(
                user.displayName ?? "User",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              
              // Email
              Text(
                user.email ?? "No Email",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),

              const SizedBox(height: 24),

              // JURISDICTION & TAX BODY SECTION
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final jurisdiction = data['jurisdiction'] as String? ?? 'Unknown';
                  final taxBody = data['taxBody'] as String? ?? 'Unknown';
                  final savedWorkType = data['workType'] as String?;
                  final loading = snapshot.connectionState == ConnectionState.waiting;

                  // Initialize selected work type from Firestore
                  if (_savedWorkType != savedWorkType) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _savedWorkType = savedWorkType;
                          _selectedWorkType = savedWorkType;
                        });
                      }
                    });
                  }

                  if (jurisdiction == 'Unknown' && !loading) return const SizedBox.shrink();

                  return Column(
                    children: [
                      // Jurisdiction & Tax Body Card
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Jurisdiction
                            Column(
                              children: [
                                Text(
                                  _getFlagForJurisdiction(jurisdiction),
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  jurisdiction,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Jurisdiction",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Divider
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey[800],
                            ),

                            // Tax Body
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: cyanBrand.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: cyanBrand, size: 18),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  taxBody,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Tax Body",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // WORK TYPE SECTION
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Work Type",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Personalize AI analysis for your occupation",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Work Type Options
                            _buildWorkTypeCard(
                              context,
                              value: 'EMPLOYED',
                              icon: Icons.business_center,
                              title: 'Employed',
                              subtitle: 'Salaried employee',
                              isSelected: _selectedWorkType == 'EMPLOYED',
                            ),
                            const SizedBox(height: 10),
                            _buildWorkTypeCard(
                              context,
                              value: 'SELF_EMPLOYED',
                              icon: Icons.laptop_mac,
                              title: 'Self-Employed',
                              subtitle: 'Freelancer / Consultant',
                              isSelected: _selectedWorkType == 'SELF_EMPLOYED',
                            ),
                            const SizedBox(height: 10),
                            _buildWorkTypeCard(
                              context,
                              value: 'BUSINESS',
                              icon: Icons.store,
                              title: 'Business',
                              subtitle: 'Business owner / Company',
                              isSelected: _selectedWorkType == 'BUSINESS',
                            ),

                            // Save Button (only show if changed)
                            if (_selectedWorkType != _savedWorkType) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : () => _saveWorkType(user.uid),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cyanBrand,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          "SAVE WORK TYPE",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 8),

              // Subscription Status & Management
              Consumer<SubscriptionProvider>(
                builder: (context, subscriptionProvider, _) {
                  final plan = subscriptionProvider.currentPlan;
                  final isPro = plan != 'free';
                  
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: plan == 'elite'
                              ? LinearGradient(
                                  colors: [FylloColors.defaultCyan, FylloColors.secondaryBlue],
                                )
                              : null,
                          color: plan == 'elite' ? null : (plan == 'pro' ? FylloColors.defaultCyan.withOpacity(0.2) : Colors.grey[900]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: plan == 'free' ? Colors.grey[800]! : FylloColors.defaultCyan,
                          ),
                        ),
                        child: Text(
                          "Current Plan: ${plan.toUpperCase()}",
                          style: GoogleFonts.plusJakartaSans(
                            color: plan == 'elite' ? Colors.black : (plan == 'pro' ? FylloColors.defaultCyan : Colors.grey[400]),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      
                      if (isPro) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => RevenueCatService.manageSubscription(),
                            icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                            label: Text(
                              "MANAGE SUBSCRIPTION",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FylloColors.defaultCyan,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),

              // Delete Account Button (Vault Style)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDeleteConfirmation(context, authProvider),
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  label: Text(
                    "DELETE ACCOUNT",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkTypeCard(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    const Color cyanBrand = Color(0xFF00D1FF);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWorkType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? cyanBrand.withOpacity(0.1) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cyanBrand : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? cyanBrand.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? cyanBrand : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: cyanBrand, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWorkType(String uid) async {
    setState(() => _isSaving = true);
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'workType': _selectedWorkType,
      });
      
      setState(() {
        _savedWorkType = _selectedWorkType;
      });
      
      if (mounted) {
        FylloSnackBar.showSuccess(context, "Work type saved successfully!");
      }
    } catch (e) {
      if (mounted) {
        FylloSnackBar.showError(context, "Failed to save: $e");
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showDeleteConfirmation(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Account?",
          style: GoogleFonts.plusJakartaSans(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Please cancel your active subscription in the store before deleting your account. This action is irreversible and does not automatically stop recurring charges.",
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.plusJakartaSans(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                await authProvider.deleteAccount(context);
                // Phoenix handles the restart, so no nav needed here
              } catch (e) {
                if (context.mounted) {
                  FylloSnackBar.showError(
                    context,
                    e.toString(),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(
              "Delete",
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getFlagForJurisdiction(String code) {
    switch (code.toUpperCase()) {
      case 'USA': return '🇺🇸';
      case 'UK': return '🇬🇧';
      case 'CANADA': return '🇨🇦';
      case 'AUSTRALIA': return '🇦🇺';
      case 'INDIA': return '🇮🇳';
      case 'SINGAPORE': return '🇸🇬';
      case 'UAE': return '🇦🇪';
      case 'IRELAND': return '🇮🇪';
      default: return '🌍';
    }
  }
}
