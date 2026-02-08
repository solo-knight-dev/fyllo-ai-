import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_constants.dart';

/// RevenueCat Service for managing subscriptions
class RevenueCatService {
  static const String _apiKey = 'goog_NIXvluSWEwiwDArbCjgPHtGfTny';
  
  static bool _isInitialized = false;

  /// Initialize RevenueCat SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final configuration = PurchasesConfiguration(_apiKey);
      // In newer versions, appUserID can be null in the constructor or left as default
      
      await Purchases.configure(configuration);

      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      _isInitialized = true;
      debugPrint('✅ RevenueCat initialized successfully');
    } catch (e) {
      debugPrint('❌ RevenueCat initialization failed: $e');
      rethrow;
    }
  }

  /// Set user ID when user logs in
  static Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('✅ RevenueCat user logged in: $userId');
    } catch (e) {
      debugPrint('❌ RevenueCat login failed: $e');
    }
  }

  /// Clear user ID when user logs out
  static Future<void> clearUserId() async {
    try {
      await Purchases.logOut();
      debugPrint('✅ RevenueCat user logged out');
    } catch (e) {
      debugPrint('❌ RevenueCat logout failed: $e');
    }
  }

  /// Get current customer info
  static Future<CustomerInfo> getCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo;
    } catch (e) {
      debugPrint('❌ Failed to get customer info: $e');
      rethrow;
    }
  }

  /// Get available offerings
  static Future<Offerings> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      debugPrint('❌ Failed to get offerings: $e');
      rethrow;
    }
  }

  /// Purchase a package
  static Future<CustomerInfo> purchasePackage(Package package, {String? upgradeFromProductId}) async {
    try {
      final purchaserInfo = await Purchases.purchasePackage(
        package,
        googleProductChangeInfo: upgradeFromProductId != null
            ? GoogleProductChangeInfo(
                upgradeFromProductId,
                prorationMode: GoogleProrationMode.immediateWithTimeProration,
              )
            : null,
      );
      debugPrint('✅ Purchase successful');
      return purchaserInfo.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ User cancelled purchase');
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        debugPrint('❌ Purchase not allowed');
      } else if (errorCode == PurchasesErrorCode.productNotAvailableForPurchaseError) {
        debugPrint('❌ Product not available for purchase');
        debugPrint('   Troubleshooting Guide:');
        debugPrint('   1. ⚠️ YOU ARE LIKELY RUNNING A DEBUG BUILD. Google Play Billing often fails in debug mode.');
        debugPrint('   2. Try running: "flutter run --release"');
        debugPrint('   3. Ensure your Google account is added as a "License Tester" in Play Console.');
        debugPrint('   4. Ensure the app is published to Internal/Closed testing track.');
        throw 'Setup Error: Google Play cannot process this purchase in Debug mode. Please try a Release build or check License Testing.';
      } else {
        debugPrint('❌ Purchase failed: ${e.message}');
      }
      rethrow;
    }
  }

  /// Get products directly by ID (Bypassing Offerings)
  static Future<List<StoreProduct>> getProducts(List<String> productIds) async {
    try {
      final products = await Purchases.getProducts(productIds);
      return products;
    } catch (e) {
      debugPrint('❌ Failed to get products: $e');
      return [];
    }
  }

  /// Purchase a product by looking it up via entitlement/product ID directly
  /// This is used when proper Offerings are not configured in RevenueCat
  static Future<CustomerInfo?> purchaseProductByEntitlement(String entitlementId, {String? upgradeFromProductId}) async {
    try {
      debugPrint('🔍 Attempting to purchase via direct product lookup for entitlement: $entitlementId');
      
      String targetProductId;
      if (entitlementId == FylloPlans.proEntitlement) {
        targetProductId = FylloPlans.proMonthlyProductId;
      } else if (entitlementId == FylloPlans.eliteEntitlement) {
        targetProductId = FylloPlans.eliteMonthlyProductId;
      } else {
        throw 'Unknown entitlement ID: $entitlementId';
      }

      // 1. Try fetching with full ID (e.g. pro_monthly:monthly)
      var products = await getProducts([targetProductId]);
      
      // 2. Fallback: If not found, try fetching with just Subscription ID (e.g. pro_monthly)
      // This is necessary because "Backwards Compatible" products might be exposed as just the Sub ID
      if (products.isEmpty && targetProductId.contains(':')) {
        final basicProductId = targetProductId.split(':').first;
        debugPrint('⚠️ Full ID $targetProductId not found. Trying fallback ID: $basicProductId');
        products = await getProducts([basicProductId]);
      }
      
      if (products.isNotEmpty) {
        debugPrint('✅ Found product ${products.first.identifier} for entitlement $entitlementId');
        return await purchaseProduct(products.first, upgradeFromProductId: upgradeFromProductId);
      }
      
      debugPrint('❌ No product found for entitlement: $entitlementId (Target ID: $targetProductId)');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to purchase by entitlement: $e');
      rethrow;
    }
  }

  /// Get all available products for diagnostics
  static Future<Map<String, dynamic>> getAllAvailableProducts() async {
    try {
      final offerings = await getOfferings();
      final products = <String, dynamic>{};
      
      products['offeringsCount'] = offerings.all.length;
      products['currentOffering'] = offerings.current?.identifier ?? 'None';
      
      final allProducts = <Map<String, String>>[];
      for (var offering in offerings.all.values) {
        for (var package in offering.availablePackages) {
          allProducts.add({
            'offering': offering.identifier,
            'packageId': package.identifier,
            'productId': package.storeProduct.identifier,
            'title': package.storeProduct.title,
            'price': package.storeProduct.priceString,
          });
        }
      }
      products['products'] = allProducts;
      
      return products;
    } catch (e) {
      debugPrint('❌ Failed to get available products: $e');
      return {'error': e.toString()};
    }
  }

  /// Purchase a product directly - Recommended to use purchasePackage instead
  static Future<CustomerInfo> purchaseProduct(StoreProduct product, {String? upgradeFromProductId}) async {
    try {
      final purchaserInfo = await Purchases.purchaseStoreProduct(
        product,
        googleProductChangeInfo: upgradeFromProductId != null
            ? GoogleProductChangeInfo(
                upgradeFromProductId,
                prorationMode: GoogleProrationMode.immediateWithTimeProration,
              )
            : null,
      );
      debugPrint('✅ Purchase successful');
      return purchaserInfo.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ User cancelled purchase');
      } else {
        debugPrint('❌ Purchase failed: ${e.message}');
      }
      rethrow;
    }
  }

  /// Restore purchases
  static Future<CustomerInfo> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      debugPrint('✅ Purchases restored');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ Failed to restore purchases: $e');
      rethrow;
    }
  }

  /// Check if user has Pro entitlement
  static Future<bool> hasProAccess() async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(FylloPlans.proEntitlement);
    } catch (e) {
      return false;
    }
  }

  /// Check if user has Elite entitlement
  static Future<bool> hasEliteAccess() async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(FylloPlans.eliteEntitlement);
    } catch (e) {
      return false;
    }
  }

  /// Get current plan (free, pro, or elite)
  static Future<String> getCurrentPlan() async {
    try {
      final customerInfo = await getCustomerInfo();
      
      if (customerInfo.entitlements.active.containsKey(FylloPlans.eliteEntitlement)) {
        return FylloPlans.elite;
      } else if (customerInfo.entitlements.active.containsKey(FylloPlans.proEntitlement)) {
        return FylloPlans.pro;
      } else {
        return FylloPlans.free;
      }
    } catch (e) {
      return FylloPlans.free;
    }
  }

  /// Check if user has access to a specific feature
  static Future<bool> hasFeatureAccess(String feature) async {
    final plan = await getCurrentPlan();
    
    switch (feature) {
      case 'pdf_export':
        return plan == FylloPlans.pro || plan == FylloPlans.elite;
      case 'advanced_insights':
        return plan == FylloPlans.pro || plan == FylloPlans.elite;
      case 'priority_support':
        return plan == FylloPlans.elite;
      case 'custom_reports':
        return plan == FylloPlans.elite;
      default:
        return false;
    }
  }

  /// Manage Subscription (Open Store)
  static Future<void> manageSubscription() async {
    try {
      final customerInfo = await getCustomerInfo();
      final managementURL = customerInfo.managementURL;

      Uri? uri;
      if (managementURL != null && managementURL.isNotEmpty) {
        uri = Uri.parse(managementURL);
      } else {
        // Fallback URLs
        if (Platform.isAndroid) {
          uri = Uri.parse('https://play.google.com/store/account/subscriptions');
        } else if (Platform.isIOS) {
          uri = Uri.parse('https://apps.apple.com/account/subscriptions');
        }
      }

      if (uri != null) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('❌ Could not launch subscription management URL: $uri');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to open subscription management: $e');
    }
  }
}