/// Economy models for Nertz Royale
/// Defines currency balances, transactions, inventory, and shop products.

library;

/// User's currency balance
class CurrencyBalance {
  final String userId;
  final int coins;
  final int gems;
  final DateTime updatedAt;

  const CurrencyBalance({
    required this.userId,
    required this.coins,
    required this.gems,
    required this.updatedAt,
  });

  factory CurrencyBalance.empty(String userId) => CurrencyBalance(
    userId: userId,
    coins: 0,
    gems: 0,
    updatedAt: DateTime.now(),
  );

  factory CurrencyBalance.fromJson(Map<String, dynamic> json) {
    return CurrencyBalance(
      userId: json['user_id'] as String,
      coins: json['coins'] as int? ?? 0,
      gems: json['gems'] as int? ?? 0,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'coins': coins,
    'gems': gems,
    'updated_at': updatedAt.toIso8601String(),
  };

  CurrencyBalance copyWith({int? coins, int? gems}) {
    return CurrencyBalance(
      userId: userId,
      coins: coins ?? this.coins,
      gems: gems ?? this.gems,
      updatedAt: DateTime.now(),
    );
  }
}

/// Transaction record for audit trail
class EconomyTransaction {
  final String id;
  final String userId;
  final String currency; // 'coins' or 'gems'
  final int amount; // positive = credit, negative = debit
  final String source; // 'game_reward', 'iap_purchase', 'shop_spend'
  final String? referenceId;
  final DateTime createdAt;

  const EconomyTransaction({
    required this.id,
    required this.userId,
    required this.currency,
    required this.amount,
    required this.source,
    this.referenceId,
    required this.createdAt,
  });

  factory EconomyTransaction.fromJson(Map<String, dynamic> json) {
    return EconomyTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      currency: json['currency'] as String,
      amount: json['amount'] as int,
      source: json['source'] as String,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Shop product definition
class ShopProduct {
  final String id;
  final String name;
  final String? description;
  final String category; // 'card_back', 'avatar', 'sound', 'game_mode'
  final int priceCoins;
  final int priceGems;
  final String? assetPath;
  final bool isAvailable;
  final int sortOrder;

  const ShopProduct({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.priceCoins,
    required this.priceGems,
    this.assetPath,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    return ShopProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      priceCoins: json['price_coins'] as int? ?? 0,
      priceGems: json['price_gems'] as int? ?? 0,
      assetPath: json['asset_path'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  /// Whether this item costs real money (gems only)
  bool get isPremium => priceGems > 0 && priceCoins == 0;
  
  /// Whether this item is free
  bool get isFree => priceCoins == 0 && priceGems == 0;
}

/// Inventory item (owned by user)
class InventoryItem {
  final String id;
  final String userId;
  final String itemId;
  final DateTime acquiredAt;

  const InventoryItem({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.acquiredAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      itemId: json['item_id'] as String,
      acquiredAt: DateTime.parse(json['acquired_at'] as String),
    );
  }
}
