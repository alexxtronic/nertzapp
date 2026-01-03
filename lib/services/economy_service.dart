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

      final products = (response as List)
          .map((json) => ShopProduct.fromJson(json))
          .toList();

      return products;
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
  /// Rule: 1 coin per 1 point (1:1 ratio)
  static int calculateCoinsEarned(int roundScore) {
    if (roundScore <= 0) return 0;
    return roundScore;
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
  /// Supports both legacy hardcoded IDs and new dynamic format
  static String getCardBackAssetPath(String itemId) {
    // Handle legacy/known IDs
    switch (itemId) {
      case 'card_back_classic_default':
        return 'assets/card_back.png';
      case 'card_back_classic_gold':
        return 'assets/card_backs/classic_gold.png';
      case 'card_back_classic_cosmic':
        return 'assets/card_backs/classic_cosmic.png';
      case 'card_back_hippie_cosmic':
        return 'assets/card_backs/hippie_cosmic.png';
      case 'card_back_medieval_blue':
        return 'assets/card_backs/medieval_blue.png';
      case 'card_back_medieval_red':
        return 'assets/card_backs/medieval_red.png';
      case 'card_back_swamp':
        return 'assets/card_backs/swamp.png';
      case 'card_back_wizard_blue':
        return 'assets/card_backs/wizard_blue.png';
      case 'card_back_wizard_gold':
        return 'assets/card_backs/wizard_gold.png';
      // New card backs
      case 'card_back_3d_blue':
        return 'assets/card_backs/3d_blue.png';
      case 'card_back_3d_steel':
        return 'assets/card_backs/3d_steel.png';
      case 'card_back_alien_full':
        return 'assets/card_backs/alien_full.png';
      case 'card_back_icecream_full':
        return 'assets/card_backs/icecream_full.png';
      case 'card_back_pirate_full':
        return 'assets/card_backs/pirate_full.png';
      case 'card_back_doodle_rare':
        return 'assets/card_backs/doodle-rare.png';
      default:
        // Dynamic fallback: try to construct path from ID
        // ID format: "card_back_<name>" -> "assets/card_backs/<name>.png"
        if (itemId.startsWith('card_back_')) {
          final name = itemId.substring(10); // Remove "card_back_" prefix
          return 'assets/card_backs/$name.png';
        }
        return 'assets/card_back.png';
    }
  }

  /// Get user's currently selected music ID
  Future<String?> getSelectedMusicId() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('selected_music_id')
          .eq('id', userId)
          .single();
      
      return response['selected_music_id'] as String?;
    } catch (e) {
      print('❌ Error fetching selected music: $e');
      return null;
    }
  }

  /// Set user's selected music
  Future<bool> setSelectedMusicId(String? itemId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _supabase
          .from('profiles')
          .update({'selected_music_id': itemId})
          .eq('id', userId);

      print('🎵 Selected music: $itemId');
      return true;
    } catch (e) {
      print('❌ Error setting music: $e');
      return false;
    }
  }

  /// Get user's currently selected background ID
  Future<String?> getSelectedBackgroundId() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('selected_background_id')
          .eq('id', userId)
          .single();
      
      return response['selected_background_id'] as String?;
    } catch (e) {
      print('❌ Error fetching selected background: $e');
      return null;
    }
  }

  /// Set user's selected background
  Future<bool> setSelectedBackgroundId(String? itemId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _supabase
          .from('profiles')
          .update({'selected_background_id': itemId})
          .eq('id', userId);

      print('🖼️ Selected background: $itemId');
      return true;
    } catch (e) {
      print('❌ Error setting background: $e');
      return false;
    }
  }


}
