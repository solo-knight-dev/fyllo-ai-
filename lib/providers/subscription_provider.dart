import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';
import '../utils/app_constants.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Subscription Provider for managing subscription state
class SubscriptionProvider extends ChangeNotifier {
  String _currentPlan = FylloPlans.free;
  CustomerInfo? _customerInfo;
  bool _isLoading = false;

  String get currentPlan => _currentPlan;
  CustomerInfo? get customerInfo => _customerInfo;
  bool get isLoading => _isLoading;

  // Convenience getters
  bool get isFree => _currentPlan == FylloPlans.free;
  bool get isPro => _currentPlan == FylloPlans.pro;
  bool get isElite => _currentPlan == FylloPlans.elite;
  bool get isPremium => isPro || isElite;

  /// Initialize and load subscription status
  Future<void> initialize() async {
    debugPrint('🔄 Initializing SubscriptionProvider...');
    await loadSubscriptionStatus();
  }

  /// Load current subscription status from RevenueCat
  Future<void> loadSubscriptionStatus() async {
    try {
      _setLoading(true);
      
      final customerInfo = await RevenueCatService.getCustomerInfo();
      _customerInfo = customerInfo;
      
      // Determine current plan based on entitlements
      // RevenueCat source of truth
      if (customerInfo.entitlements.active.containsKey(FylloPlans.eliteEntitlement)) {
        _currentPlan = FylloPlans.elite;
      } else if (customerInfo.entitlements.active.containsKey(FylloPlans.proEntitlement)) {
        _currentPlan = FylloPlans.pro;
      } else {
        _currentPlan = FylloPlans.free;
      }
      
      debugPrint('📱 Current plan: $_currentPlan');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to load subscription status: $e');
      _currentPlan = FylloPlans.free;
    } finally {
      _setLoading(false);
    }
  }

  /// Get the currently active product ID (if any)
  String? get activeProductId {
    if (_customerInfo == null) return null;
    if (isPro) {
       return _customerInfo?.entitlements.all[FylloPlans.proEntitlement]?.productIdentifier;
    }
    if (isElite) {
       return _customerInfo?.entitlements.all[FylloPlans.eliteEntitlement]?.productIdentifier;
    }
    return null;
  }

  /// Purchase a package - Returns true if successful, false if cancelled, throws on error
  Future<bool> purchasePackage(BuildContext context, Package package) async {
    try {
      _setLoading(true);
      
      // 1. Logic to handle Upgrades/Downgrades
      // If we have an active subscription and are buying a DIFFERENT one, we pass the old ID.
      String? oldProductId;
      final currentId = activeProductId;
      final targetId = package.storeProduct.identifier;

      if (currentId != null && currentId != targetId) {
         oldProductId = currentId;
         debugPrint('🔄 Subscription Switch Detected. Upgrading/Downgrading from: $oldProductId to $targetId');
      }

      // 2. Perform Purchase
      final customerInfo = await RevenueCatService.purchasePackage(
        package, 
        upgradeFromProductId: oldProductId, // Passes the old ID for proration/upgrade
      );
      _customerInfo = customerInfo;
      
      
      // 3. Update Local State
      await loadSubscriptionStatus();

      // 3.5 Sync credits secure
      await _syncCreditsSecurely();

      // 4. Restart App on Success
      // We wait briefly to allow the UI to show the "Success" snackbar, then reboot.
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (context.mounted) {
          debugPrint('🔄 Purchase successful. Restarting app via Phoenix...');
          Phoenix.rebirth(context);
        }
      });
      
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ User cancelled purchase');
        return false; // Return false for cancellation (not an error)
      } else if (errorCode == PurchasesErrorCode.storeProblemError) {
        throw 'Store unavailable. Please try again later.';
      } else if (errorCode == PurchasesErrorCode.productNotAvailableForPurchaseError) {
        throw 'Product not available. Please try again later.';
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        throw 'Purchase not allowed. Check payment settings.';
      } else {
        // Pass specifically formatted error messages for known issues
        if (e.message?.contains('Billing is not available') ?? false) {
           throw 'Billing issue. Check connection.';
        }
        throw 'Purchase failed. Please try again.';
      }
    } catch (e) {
      debugPrint('❌ Purchase failed: $e');
      throw 'Purchase failed. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  /// Purchase by entitlement ID (fallback method)
  /// Returns true if successful, false if cancelled, throws on error
  Future<bool> purchaseByEntitlement(BuildContext context, String entitlementId) async {
    try {
      _setLoading(true);
      
      debugPrint('🔄 Attempting entitlement-based purchase: $entitlementId');
      
      // Logic to handle Upgrades/Downgrades
      String? oldProductId;
      final currentId = activeProductId;
      
      // If we are Pro and buying Elite (or vice-versa), we switch.
      bool isSwitching = false;
      if (entitlementId == FylloPlans.proEntitlement && isElite) isSwitching = true;
      if (entitlementId == FylloPlans.eliteEntitlement && isPro) isSwitching = true;

      if (isSwitching && currentId != null) {
        oldProductId = currentId;
        debugPrint('🔄 Entitlement Switch Detected. Switching from: $oldProductId');
      }

      final customerInfo = await RevenueCatService.purchaseProductByEntitlement(
        entitlementId,
        upgradeFromProductId: oldProductId,
      );
      
      if (customerInfo == null) {
        throw 'Product not available.';
      }
      
      _customerInfo = customerInfo;
      await loadSubscriptionStatus();
      await _syncCreditsSecurely();
      
      // Restart app
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (context.mounted) {
          Phoenix.rebirth(context);
        }
      });
      
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
       throw 'Purchase failed. Please try again.';
    } catch (e) {
      debugPrint('❌ Entitlement purchase failed: $e');
      throw 'Purchase failed. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  /// Restore purchases - Returns true if successful with active entitlements, false if no purchases found
  Future<bool> restorePurchases(BuildContext context) async {
    try {
      _setLoading(true);
      
      final customerInfo = await RevenueCatService.restorePurchases();
      _customerInfo = customerInfo;
      
      // Update current plan
      await loadSubscriptionStatus();

      // Sync credits
      await _syncCreditsSecurely();

      // Check if user has any active entitlements
      final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;

      if (hasActiveSubscription) {
        // restart app
        Phoenix.rebirth(context);
      }
      
      return hasActiveSubscription;
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if user has access to a specific feature
  bool hasFeatureAccess(String feature) {
    switch (feature) {
      case 'pdf_export':
        return isPro || isElite;
      case 'advanced_insights':
        return isPro || isElite;
      case 'priority_support':
        return isElite;
      case 'custom_reports':
        return isElite;
      case 'unlimited_scans':
        return isElite;
      default:
        return false;
    }
  }

  /// Get remaining scans for current plan
  int getRemainingScans(int currentScans) {
    if (isElite) {
      return FylloFeatures.eliteExpenseScans - currentScans;
    } else if (isPro) {
      return FylloFeatures.proExpenseScans - currentScans;
    } else {
      return FylloFeatures.freeExpenseScans - currentScans;
    }
  }

  /// Check if user can scan more expenses
  bool canScanMore(int currentScans) {
    if (isElite) {
      return currentScans < FylloFeatures.eliteExpenseScans;
    } else if (isPro) {
      return currentScans < FylloFeatures.proExpenseScans;
    } else {
      return currentScans < FylloFeatures.freeExpenseScans;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Sync credits via secure cloud function
  /// This ensures instant credit updates without waiting for RevenueCat webhook
  Future<void> _syncCreditsSecurely() async {
    try {
      debugPrint('🔄 Syncing credits via secure Cloud Function...');
      
      // Using generic callable function that uses REST API
      final callable = FirebaseFunctions.instance.httpsCallable('syncSubscriptionCredits');
      final result = await callable.call();
      
      debugPrint('✅ Credits synced: ${result.data}');
    } catch (e) {
      debugPrint('⚠️ Failed to sync credits (webhook will handle it): $e');
      // Non-critical error - webhook will sync eventually
    }
  }
}