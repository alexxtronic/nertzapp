/// Economy service for Nertz Royale
/// Handles all currency operations via Supabase with server-authoritative balances.

library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/economy.dart';

class EconomyService {
  static final EconomyService _instance = EconomyService._internal();
  factory EconomyService() => _instance;
  EconomyService._internal();

  final _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Check if user is online (has active Supabase connection)
  bool get isOnline {
    try {
      return _supabase.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Get current user's balance
  Future<CurrencyBalance?> getBalance() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_balances')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Balance row doesn't exist yet, return empty
        return CurrencyBalance.empty(userId);
      }

      return CurrencyBalance.fromJson(response);
    } catch (e) {
      print('❌ Error fetching balance: $e');
      return null;
    }
  }

  /// Award coins to user (calls server RPC for atomicity)
  /// Returns new balance, or null if offline/error
  Future<int?> awardCoins({
    required int amount,
    required String source,
    String? referenceId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      print('⚠️ Cannot award coins: user not logged in');
      return null;
    }

    if (amount <= 0) {
      print('⚠️ Cannot award coins: amount must be positive');
      return null;
    }

    try {
      final result = await _supabase.rpc('award_coins', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_source': source,
        'p_reference_id': referenceId,
      });

      print('💰 Awarded $amount coins! New balance: $result');
      return result as int?;
    } catch (e) {
      print('❌ Error awarding coins: $e');
      return null;
    }
  }

  /// Spend currency to purchase an item (atomic purchase)
  Future<bool> purchaseItem({
    required String itemId,
    required String currency, // 'coins' or 'gems'
    required int price,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _supabase.rpc('spend_currency', params: {
        'p_user_id': userId,
        'p_item_id': itemId,
        'p_currency': currency,
        'p_amount': price,
      });

      print('🛒 Purchased item: $itemId for $price $currency');
      return true;
    } catch (e) {
      print('❌ Purchase failed: $e');
      return false;
    }
  }

  /// Get user's inventory
  Future<List<InventoryItem>> getInventory() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('user_inventory')
          .select()
          .eq('user_id', userId)
          .order('acquired_at', ascending: false);

      return (response as List)
          .map((json) => InventoryItem.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching inventory: $e');
      return [];
    }
  }

  /// Check if user owns a specific item
  Future<bool> ownsItem(String itemId) async {
    final inventory = await getInventory();
    return inventory.any((item) => item.itemId == itemId);
  }

  /// Get shop catalog
  Future<List<ShopProduct>> getShopProducts() async {
    try {
      final response = await _supabase
          .from('shop_products')
          .select()
          .eq('is_available', true)
          .order('sort_order');

      return (response as List)
          .map((json) => ShopProduct.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching shop products: $e');
      return [];
    }
  }

  /// Get transaction history
  Future<List<EconomyTransaction>> getTransactionHistory({int limit = 50}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => EconomyTransaction.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching transactions: $e');
      return [];
    }
  }

  /// Calculate coins earned from a round score
  /// Rule: 1 coin per 10 net positive points
  static int calculateCoinsEarned(int roundScore) {
    if (roundScore <= 0) return 0;
    return roundScore ~/ 10;
  }

  /// Get user's selected card back
  Future<String> getSelectedCardBack() async {
    final userId = _currentUserId;
    if (userId == null) return 'card_back_classic_default';

    try {
      final response = await _supabase
          .from('profiles')
          .select('selected_card_back')
          .eq('id', userId)
          .maybeSingle();

      return response?['selected_card_back'] as String? ?? 'card_back_classic_default';
    } catch (e) {
      print('❌ Error fetching selected card back: $e');
      return 'card_back_classic_default';
    }
  }

  /// Set user's selected card back
  Future<bool> setSelectedCardBack(String itemId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _supabase
          .from('profiles')
          .update({'selected_card_back': itemId})
          .eq('id', userId);

      print('🎴 Selected card back: $itemId');
      return true;
    } catch (e) {
      print('❌ Error setting card back: $e');
      return false;
    }
  }

  /// Get asset path for a card back item ID
  static String getCardBackAssetPath(String itemId) {
    switch (itemId) {
      case 'card_back_classic_default':
        return 'assets/card_back.png';
      case 'card_back_classic_gold':
        return 'assets/card_backs/classic_gold.png';
      case 'card_back_classic_cosmic':
        return 'assets/card_backs/classic_cosmic.jpg';
      case 'card_back_hippie_cosmic':
        return 'assets/card_backs/hippie_cosmic.jpg';
      case 'card_back_medieval_blue':
        return 'assets/card_backs/medieval_blue.jpg';
      case 'card_back_medieval_red':
        return 'assets/card_backs/medieval_red.jpg';
      case 'card_back_swamp':
        return 'assets/card_backs/swamp.jpg';
      case 'card_back_wizard_blue':
        return 'assets/card_backs/wizard_blue.jpg';
      case 'card_back_wizard_gold':
        return 'assets/card_backs/wizard_gold.jpg';
      default:
        return 'assets/card_back.png';
    }
  }
}
