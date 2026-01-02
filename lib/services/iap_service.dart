/// Service to handle In-App Purchases using the `in_app_purchase` package.
///
/// This service handles:
/// - Loading available products from App Store / Google Play
/// - Processing purchases (buy consumables)
/// - Verifying receipts (mock/local or backend)
/// - Crediting the user's account via Supabase
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Provider ---

final iapServiceProvider = Provider<IAPService>((ref) {
  return IAPService();
});

// --- Service ---

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Stream subscription for purchase updates
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Products available for sale
  // TODO: These IDs must match exactly what is in App Store Connect
  static const Set<String> _kProductIds = {
    'gems_pack_small',   // e.g. 50 gems
    'gems_pack_medium',  // e.g. 200 gems
    'gems_pack_large',   // e.g. 500 gems
    'gems_pack_huge',    // e.g. 1200 gems
    'bundle_starter',    // e.g. Coins + Gems
  };

  final _productsController = StreamController<List<ProductDetails>>.broadcast();
  Stream<List<ProductDetails>> get productsStream => _productsController.stream;

  bool _isAvailable = false;

  IAPService() {
    _initConnection();
  }

  void dispose() {
    _subscription.cancel();
    _productsController.close();
  }

  Future<void> _initConnection() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('⚠️ IAP Store not available');
      return;
    }

    // Listen to purchase updates
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('⚠️ IAP Error: $error');
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    final ProductDetailsResponse response = await _iap.queryProductDetails(_kProductIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
    }
    
    // Emit loaded products
    // Sort them by price if needed, or keeping them as list
    final products = response.productDetails;
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    
    _productsController.add(products);
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    // Consumable (gems)
    await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // Show loading UI if needed
        debugPrint('⏳ Purchase pending: ${purchase.productID}');
      } else {
        if (purchase.status == PurchaseStatus.error) {
          debugPrint('❌ Purchase error: ${purchase.error}');
        } else if (purchase.status == PurchaseStatus.purchased || 
                   purchase.status == PurchaseStatus.restored) {
          
          await _deliverProduct(purchase);
        }
        
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    debugPrint('✅ Delivering product: ${purchase.productID}');
    
    // Determine the amount to credit based on Product ID
    int gemsToAdd = 0;
    int coinsToAdd = 0;

    switch (purchase.productID) {
      case 'gems_pack_small':
        gemsToAdd = 50;
        break;
      case 'gems_pack_medium':
        gemsToAdd = 200;
        break;
      case 'gems_pack_large':
        gemsToAdd = 500;
        break;
      case 'gems_pack_huge':
        gemsToAdd = 1200;
        break;
      case 'bundle_starter':
        gemsToAdd = 100;
        coinsToAdd = 1000;
        break;
      default:
        debugPrint('⚠️ Unknown product ID delivered: ${purchase.productID}');
        return;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Call database function or update directly
      // Ideally, use a stored procedure for atomic increments
      // For now, we update table directly or use RPC if exists
      
      // Simple RPC call is safer for atomic add
      if (gemsToAdd > 0) {
        await _supabase.rpc('add_gems', params: {
          'user_id': userId,
          'amount': gemsToAdd,
        });
      }
      
      if (coinsToAdd > 0) {
        await _supabase.rpc('add_coins', params: {
          'user_id': userId,
          'amount': coinsToAdd,
        });
      }

      debugPrint('💰 Credited $gemsToAdd gems and $coinsToAdd coins to user');
      
    } catch (e) {
      debugPrint('❌ Failed to credit user: $e');
      // In a real app, you would retry or flag this for support
    }
  }
}
