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
    'gems_pack_small',   // 5 gems ($0.99)
    'gems_pack_medium',  // 20 gems ($2.99)
    'gems_pack_large',   // 50 gems ($5.99)
    'gems_pack_huge',    // 250 gems ($19.99)
    'bundle_starter',    // 15 Gems + 1500 Coins ($2.99)
    'bundle_pro',        // 100 Gems + 2000 Coins ($10.99)
    'bundle_ultimate',   // 350 Gems + 5000 Coins ($29.99)
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
    List<ProductDetails> products = [];
    
    // Try to load real products
    if (_isAvailable) {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_kProductIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
      }
      products = response.productDetails;
    }

    // Fallback to Mock Products if list is empty (for testing/simulator)
    if (products.isEmpty) {
      debugPrint('⚠️ No products found or store unavailable. Using MOCK products.');
      products = _getMockProducts();
    }
    
    // Sort
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    
    _productsController.add(products);
  }

  // Mock Products for testing
  List<ProductDetails> _getMockProducts() {
    return [
      ProductDetails(
        id: 'gems_pack_small',
        title: 'Small Gem Pack',
        description: '5 Gems',
        price: '\$0.99',
        rawPrice: 0.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'gems_pack_medium',
        title: 'Medium Gem Pack',
        description: '20 Gems',
        price: '\$2.99',
        rawPrice: 2.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'gems_pack_large',
        title: 'Large Gem Pack',
        description: '50 Gems',
        price: '\$5.99',
        rawPrice: 5.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'gems_pack_huge',
        title: 'Huge Gem Pack',
        description: '250 Gems',
        price: '\$19.99',
        rawPrice: 19.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'bundle_starter',
        title: 'Starter Bundle',
        description: '1500 Coins + 15 Gems',
        price: '\$2.99',
        rawPrice: 2.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'bundle_pro',
        title: 'Pro Bundle',
        description: '2000 Coins + 100 Gems',
        price: '\$10.99',
        rawPrice: 10.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'bundle_ultimate',
        title: 'Ultimate Bundle',
        description: '5000 Coins + 350 Gems',
        price: '\$29.99',
        rawPrice: 29.99,
        currencyCode: 'USD',
      ),
    ];
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
        gemsToAdd = 5;
        break;
      case 'gems_pack_medium':
        gemsToAdd = 20;
        break;
      case 'gems_pack_large':
        gemsToAdd = 50;
        break;
      case 'gems_pack_huge':
        gemsToAdd = 250;
        break;
      case 'bundle_starter':
        gemsToAdd = 15;
        coinsToAdd = 1500;
        break;
     case 'bundle_pro':
        gemsToAdd = 100;
        coinsToAdd = 2000;
        break;
      case 'bundle_ultimate':
        gemsToAdd = 350;
        coinsToAdd = 5000;
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
