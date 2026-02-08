import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:fyllo_ai/providers/subscription_provider.dart';
import 'package:fyllo_ai/widgets/notifications/fyllo_snackbar.dart';
import 'package:fyllo_ai/providers/auth_provider.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyllo_ai/screens/invite_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fyllo_ai/services/revenue_cat_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _showDiagnostics = false;
  Map<String, dynamic>? _diagnosticsData;
  List<StoreProduct> _directProducts = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      // Ensure user is identified if possible
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        await Purchases.logIn(authProvider.user!.uid);
      }

      // 1. Try to load offerings (Standard method)
      try {
        final offerings = await Purchases.getOfferings();
        debugPrint('📦 RevenueCat Offerings loaded');
        if (mounted) {
          setState(() {
            _offerings = offerings;
          });
        }
      } catch (e) {
        // Suppress this error as user might not have offerings configured
        // We will fallback to direct product lookup
        debugPrint('⚠️ Offerings failed to load, which is expected if not configured: $e');
      }
      
      // 2. Pre-fetch products directly to ensure they are available
      // This warms up the cache for our fallback mechanism
      try {
        final products = await RevenueCatService.getProducts([
          FylloPlans.proMonthlyProductId, 
          FylloPlans.eliteMonthlyProductId
        ]);
        if (mounted) {
          setState(() {
            _directProducts = products;
          });
        }
        debugPrint('📦 Direct product fetch found ${products.length} products');
        for (var p in products) {
           debugPrint('   ✅ Verified Product: ${p.identifier} (${p.priceString})');
        }
      } catch (e) {
        debugPrint('⚠️ Direct product fetch also failed: $e');
      }

      // Load diagnostics data
      if (_showDiagnostics) {
        _diagnosticsData = await RevenueCatService.getAllAvailableProducts();
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadOfferings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Do NOT show error to user, as the hardcoded cards will work via fallback
      }
    }
  }

  Future<void> _handlePurchase(Package package, String planName, {String? entitlementFallback}) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FylloColors.darkGray,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: FylloColors.defaultCyan),
              const SizedBox(height: 16),
              DefaultTextStyle(
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
                child: const Text('Processing purchase...'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      final success = await subscriptionProvider.purchasePackage(context, package);
      
      if (mounted) Navigator.pop(context);
      
      if (success) {
        if (mounted) {
          FylloSnackBar.showSuccess(
            context,
            'Welcome to $planName! Restarting app to apply changes...',
            icon: Icons.celebration_rounded,
          );
        }
      } else {
        if (mounted) {
          FylloSnackBar.showWarning(
            context,
            'Purchase was cancelled',
            icon: Icons.cancel_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        String errorMessage = 'Purchase failed. Please try again.';
        
        // Use the exception message if it's a string (our custom errors from provider)
        if (e is String) {
          errorMessage = e;
        } else if (e.toString().contains('cancelled')) {
          errorMessage = 'Purchase was cancelled';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('payment')) {
          errorMessage = 'Payment method issue. Please check your payment details.';
        }
        
        // Try fallback to entitlement-based purchase if product unavailable
        if (e.toString().contains('unavailable') && entitlementFallback != null) {
          debugPrint('⚠️ Package purchase failed, trying entitlement fallback: $entitlementFallback');
          try {
            final fallbackSuccess = await Provider.of<SubscriptionProvider>(context, listen: false).purchaseByEntitlement(context, entitlementFallback);
            if (fallbackSuccess && mounted) {
              FylloSnackBar.showSuccess(
                context,
                'Welcome to $planName! Restarting app...',
                icon: Icons.celebration_rounded,
              );
              return;
            }
          } catch (fallbackError) {
            debugPrint('❌ Fallback purchase also failed: $fallbackError');
            errorMessage = 'Product not available. Please try again later.';
          }
        }
        
        FylloSnackBar.showError(
          context,
          errorMessage,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _handleDirectPurchase(String entitlementId, String planName) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FylloColors.darkGray,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: FylloColors.defaultCyan),
              const SizedBox(height: 16),
              DefaultTextStyle(
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
                child: const Text('Processing purchase...'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      final success = await subscriptionProvider.purchaseByEntitlement(context, entitlementId);
      
      if (mounted) Navigator.pop(context);
      
      if (success) {
        if (mounted) {
          FylloSnackBar.showSuccess(
            context,
            'Welcome to $planName! Restarting app...',
            icon: Icons.celebration_rounded,
          );
        }
      } else {
        if (mounted) {
          FylloSnackBar.showWarning(
            context,
            'Purchase was cancelled',
            icon: Icons.cancel_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        String errorMessage = 'Purchase failed. Please try again.';
        
        if (e is String) {
          errorMessage = e;
        } else if (e.toString().contains('cancelled')) {
          errorMessage = 'Purchase was cancelled';
        }
        
        FylloSnackBar.showError(
          context,
          errorMessage,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FylloColors.darkGray,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: FylloColors.defaultCyan),
              const SizedBox(height: 16),
              DefaultTextStyle(
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
                child: const Text('Restoring purchases...'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      final success = await subscriptionProvider.restorePurchases(context);
      
      if (mounted) Navigator.pop(context);
      
      if (success) {
        if (mounted) {
          FylloSnackBar.showSuccess(
            context,
            'Purchases restored! Restarting app...',
            icon: Icons.check_circle_rounded,
          );
        }
      } else {
        if (mounted) {
          FylloSnackBar.showInfo(
            context,
            'No purchases found to restore.',
            icon: Icons.info_outline_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        FylloSnackBar.showError(
          context,
          'Failed to restore purchases. Please try again.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return Scaffold(
      backgroundColor: FylloColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () async {
              setState(() => _isLoading = true);
              await _loadOfferings();
              if (mounted) {
                FylloSnackBar.showInfo(
                  context,
                  'Products refreshed',
                  icon: Icons.refresh_rounded,
                );
              }
            },
            icon: const Icon(Icons.refresh_rounded, color: FylloColors.defaultCyan, size: 24),
            tooltip: 'Refresh Products',
          ),
          TextButton.icon(
            onPressed: _isLoading ? null : _handleRestore,
            icon: const Icon(Icons.restore, color: FylloColors.defaultCyan, size: 20),
            label: Text(
              'Restore',
              style: GoogleFonts.plusJakartaSans(
                color: _isLoading ? Colors.grey : FylloColors.defaultCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FylloColors.defaultCyan))
          : authProvider.user == null 
              ? const Center(child: CircularProgressIndicator(color: FylloColors.defaultCyan))
              : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(authProvider.user!.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                // Show loading while waiting for first data
                if (!userSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: FylloColors.defaultCyan),
                  );
                }
                
                // Fetch dynamic pricing
                final proPackage = _findPackageByIdentifier(FylloPlans.proMonthlyProductId);
                final elitePackage = _findPackageByIdentifier(FylloPlans.eliteMonthlyProductId);
                
                String proPrice = proPackage?.storeProduct.priceString ?? 'Unavail.';
                String elitePrice = elitePackage?.storeProduct.priceString ?? 'Unavail.';

                // Fallback: Check direct products if package not found in offerings
                if (proPackage == null && _directProducts.isNotEmpty) {
                  final directPro = _directProducts.where((p) => p.identifier == FylloPlans.proMonthlyProductId).firstOrNull;
                  if (directPro != null) proPrice = directPro.priceString;
                }
                
                if (elitePackage == null && _directProducts.isNotEmpty) {
                  final directElite = _directProducts.where((p) => p.identifier == FylloPlans.eliteMonthlyProductId).firstOrNull;
                  if (directElite != null) elitePrice = directElite.priceString;
                }
                
                // Default values
                int remainingCredits = 0;
                int maxCredits = 10;
                
                if (userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  remainingCredits = userData?['AiCredits'] ?? 0;
                }
                
                // Determine max credits based on plan
                if (subscriptionProvider.isElite) {
                  maxCredits = FylloFeatures.eliteExpenseScans;
                } else if (subscriptionProvider.isPro) {
                  maxCredits = FylloFeatures.proExpenseScans;
                } else {
                  maxCredits = FylloFeatures.freeExpenseScans;
                }
                
                final usedCredits = maxCredits - remainingCredits;
                final usagePercent = remainingCredits >= 0 && maxCredits > 0
                    ? (usedCredits / maxCredits).clamp(0.0, 1.0)
                    : 0.0;
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Plan Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FylloColors.darkGray,
                              FylloColors.darkGray.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: FylloColors.defaultCyan, size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Plan',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  subscriptionProvider.currentPlan.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AI Credits Section - FIXED
                      _buildAiCreditsSection(
                        remaining: remainingCredits,
                        max: maxCredits,
                        used: usedCredits,
                        percent: usagePercent,
                        isElite: subscriptionProvider.isElite,
                      ),
                      const SizedBox(height: 32),
                      
                      Text(
                        'Choose Your Plan',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unlock the full power of AI-driven smart finance tracking and advanced insights.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Plan Cards
                      _buildPlanCard(
                        name: 'Free',
                        price: '\$0',
                        period: '/month',
                        features: [
                          '10 expense scans per month',
                          'Basic AI insights',
                          'Receipt vault storage',
                        ],
                        isCurrentPlan: subscriptionProvider.isFree,
                        isPremium: false,
                        onTap: null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Plan Cards (Dynamic pricing now fetched above)

                      _buildPlanCard(
                        name: 'Pro',
                        price: proPrice,
                        period: '/month',
                        features: [
                          '100 expense scans per month',
                          'Advanced AI insights',
                          'PDF export',
                        ],
                        isCurrentPlan: subscriptionProvider.isPro,
                        isPremium: true,
                        onTap: (subscriptionProvider.isPro || subscriptionProvider.isElite) ? null : () {
                          if (proPackage != null) {
                            _handlePurchase(proPackage, 'Pro', entitlementFallback: FylloPlans.proEntitlement);
                          } else {
                            debugPrint('⚠️ Package not found for Pro, using direct entitlement purchase');
                            _handleDirectPurchase(FylloPlans.proEntitlement, 'Pro');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPlanCard(
                        name: 'Elite',
                        price: elitePrice,
                        period: '/month',
                        features: [
                          '200 expense scans per month',
                          'Elite AI strategies',
                          'PDF export',
                        ],
                        isCurrentPlan: subscriptionProvider.isElite,
                        isPremium: true,
                        isElite: true,
                        onTap: subscriptionProvider.isElite ? null : () {
                          if (elitePackage != null) {
                            _handlePurchase(elitePackage, 'Elite', entitlementFallback: FylloPlans.eliteEntitlement);
                          } else {
                            debugPrint('⚠️ Package not found for Elite, using direct entitlement purchase');
                            _handleDirectPurchase(FylloPlans.eliteEntitlement, 'Elite');
                          }
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // THE GAMIFIED REFERRAL QUEST CARD
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const InviteScreen()),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E1E1E),
                                const Color(0xFF0D0D0D),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: FylloColors.defaultCyan.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FylloColors.defaultCyan.withOpacity(0.05),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: FylloColors.defaultCyan.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: FylloColors.defaultCyan,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "THE REFERRAL QUEST",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: FylloColors.defaultCyan,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Unlock 20 Free Credits",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Don't pay for credits. Invite a friend and you both get 20 bonus credits instantly. It's that simple.",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white60,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: FylloColors.defaultCyan,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: FylloColors.defaultCyan.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "START QUEST",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().shimmer(delay: 2.seconds, duration: 1.5.seconds, color: Colors.white.withOpacity(0.05)),

                      const SizedBox(height: 32),
                      
                      // Footer Note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FylloColors.darkGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: FylloColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Credits reset on the 1st of every month. Unused credits do not roll over. Don’t forget to use your credits before the month ends — especially those gained from referrals',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Package? _findPackageByIdentifier(String identifier) {
    if (_offerings == null) {
      debugPrint('❌ _findPackageByIdentifier: _offerings is null');
      return null;
    }
    
    debugPrint('🔎 Searching for package identifier: $identifier');
    
    // 1. Try search in ALL offerings and ALL packages
    for (var offering in _offerings!.all.values) {
      debugPrint('   🔍 Checking Offering: ${offering.identifier}');
      for (var package in offering.availablePackages) {
        final storeId = package.storeProduct.identifier;
        final pkgId = package.identifier;
        
        debugPrint('      🔸 Checking Store: $storeId, Pkg: $pkgId');

        // Match against Store Product ID (e.g. pro_monthly:monthly)
        if (storeId == identifier) {
          debugPrint('      ✅ MATCH: Store Product ID');
          return package;
        }
        
        // Match against Package Identifier (e.g. $rc_monthly)
        if (pkgId == identifier) {
          debugPrint('      ✅ MATCH: Package Identifier');
          return package;
        }
        
        // Match against base ID (e.g. pro_monthly)
        final baseId = identifier.split(':').first;
        if (storeId == baseId || pkgId == baseId) {
          debugPrint('      ✅ MATCH: Base ID');
          return package;
        }
        
        // Match against suffix (e.g. monthly)
        final lastPart = identifier.split(':').last;
        if (storeId == lastPart || pkgId == lastPart) {
          debugPrint('      ✅ MATCH: Suffix');
          return package;
        }

        // Fuzzy match
        if (storeId.contains(baseId) || baseId.contains(storeId)) {
          debugPrint('      ✅ MATCH: Fuzzy match');
          return package;
        }
      }
    }

    // 2. Try match against current offering specifically (most common source)
    if (_offerings!.current != null) {
      debugPrint('   🔍 Checking Current Offering: ${_offerings!.current!.identifier}');
      final baseId = identifier.split(':').first;
      for (var package in _offerings!.current!.availablePackages) {
        if (package.storeProduct.identifier.contains(baseId) || package.identifier.contains(baseId)) {
          debugPrint('      ✅ MATCH: Current Offering fuzzy');
          return package;
        }
      }
    }
    
    // 3. ULTIMATE FALLBACK: Match ANY package that contains the keywords
    final keyword = identifier.split('_').first.toLowerCase();
    debugPrint('   🔍 ULTIMATE FALLBACK: Searching for keyword "$keyword"');
    for (var offering in _offerings!.all.values) {
      for (var package in offering.availablePackages) {
        final fullData = '${package.storeProduct.identifier} ${package.identifier} ${package.storeProduct.title}'.toLowerCase();
        if (fullData.contains(keyword)) {
          debugPrint('      ✅ MATCH: Ultimate Fallback matched "$keyword" in "$fullData"');
          return package;
        }
      }
    }

    debugPrint('❌ NO PACKAGE FOUND for identifier: $identifier');
    return null;
  }

  // FIXED: AI Credits Section - No more red flash
  Widget _buildAiCreditsSection({
    required int remaining,
    required int max,
    required int used,
    required double percent,
    required bool isElite,
  }) {
    // Calculate days until reset
    final now = DateTime.now();
    final nextReset = DateTime(now.year, now.month + 1, 1);
    final daysUntilReset = nextReset.difference(now).inDays;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FylloColors.darkGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: percent > 0.9 ? FylloColors.error.withOpacity(0.3) : FylloColors.defaultCyan.withOpacity(0.1),
        ),
      ),
      child: GestureDetector(
        onLongPress: () async {
          setState(() => _showDiagnostics = !_showDiagnostics);
          
          // Load diagnostics data when enabled
          if (_showDiagnostics) {
            _diagnosticsData = await RevenueCatService.getAllAvailableProducts();
            setState(() {});
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Diagnostics ${_showDiagnostics ? 'enabled' : 'disabled'}')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showDiagnostics) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEBUG INFO', style: GoogleFonts.robotoMono(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text('User: ${Provider.of<AuthProvider>(context, listen: false).user?.uid ?? 'Anonymous'}', style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white)),
                    Text('Offerings: ${_offerings?.all.keys.join(', ') ?? 'None'}', style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white)),
                    const Divider(color: Colors.white24),
                    if (_diagnosticsData != null) ...[
                      Text('📊 Products Available: ${(_diagnosticsData!['products'] as List?)?.length ?? 0}', style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
                      if (_diagnosticsData!['products'] != null)
                        for (var product in _diagnosticsData!['products'] as List)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ${product['productId']}', style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.greenAccent)),
                                Text('  Offering: ${product['offering']} | Package: ${product['packageId']}', style: GoogleFonts.robotoMono(fontSize: 8, color: Colors.white54)),
                                Text('  Price: ${product['price']}', style: GoogleFonts.robotoMono(fontSize: 8, color: Colors.white54)),
                              ],
                            ),
                          ),
                    ] else if (_offerings != null) ...[
                      for (var o in _offerings!.all.values)
                        for (var p in o.availablePackages)
                          Text(' • [${o.identifier}] ${p.storeProduct.identifier}', style: GoogleFonts.robotoMono(fontSize: 8, color: Colors.greenAccent)),
                    ],
                    const Divider(color: Colors.white24),
                    Text('⚠️ Testing Requirements:', style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    Text('  1. Use RELEASE build', style: GoogleFonts.robotoMono(fontSize: 8, color: Colors.white70)),
                    Text('  2. Add account as License Tester', style: GoogleFonts.robotoMono(fontSize: 8, color: Colors.white70)),
                    Text('  3. Sign in to Play Store on device', style: GoogleFonts.robotoMono(fontSize: 8, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Credits Remaining',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$remaining',
                        style: GoogleFonts.plusJakartaSans(
                          color: FylloColors.defaultCyan,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/month',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.9 ? FylloColors.error : FylloColors.defaultCyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FylloColors.defaultCyan.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded, color: FylloColors.defaultCyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Credits will refresh in $daysUntilReset day${daysUntilReset == 1 ? '' : 's'}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isElite 
                ? 'You have plenty of scans available for your business.'
                : (percent > 0.8 
                    ? 'You\'re almost out of credits. Consider upgrading to avoid limits.'
                    : 'Unused credits don\'t roll over. Use them before month-end!'),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required String period,
    required List<String> features,
    required bool isCurrentPlan,
    required bool isPremium,
    bool isElite = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isElite
            ? const LinearGradient(
                colors: [
                  FylloColors.darkGray,
                  Color(0xFF151515),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isElite ? null : FylloColors.darkGray,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrentPlan
              ? FylloColors.defaultCyan
              : (isElite ? FylloColors.defaultCyan.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // Align to top
              children: [
                Expanded( // Added Expanded to prevent overflow
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/logo/logo.png',
                            width: 28, // Slightly smaller logo
                            height: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 22, // Reduced from 24
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                FylloColors.defaultCyan,
                                FylloColors.secondaryBlue,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              price,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 26, // Reduced from 32
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 2),
                            child: Text(
                              period,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isElite) ...[ 
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: FylloColors.defaultCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: FylloColors.defaultCyan.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: GoogleFonts.plusJakartaSans(
                              color: FylloColors.defaultCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCurrentPlan)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: FylloColors.defaultCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.5)),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.plusJakartaSans(
                        color: FylloColors.defaultCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: FylloColors.defaultCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan
                      ? Colors.white24
                      : (isElite
                          ? FylloColors.secondaryBlue
                          : FylloColors.defaultCyan),
                  foregroundColor: isCurrentPlan ? Colors.white54 : FylloColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isCurrentPlan ? 'Current Plan' : (isPremium ? 'Upgrade Now' : 'Current Plan'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}