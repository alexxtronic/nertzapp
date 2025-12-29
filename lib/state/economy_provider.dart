/// Economy state providers for Nertz Royale
/// Riverpod providers for currency balance, inventory, and shop data.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/economy.dart';
import '../services/economy_service.dart';

/// Provider for current user's balance
/// Auto-refreshes when invalidated
final balanceProvider = FutureProvider<CurrencyBalance?>((ref) async {
  return await EconomyService().getBalance();
});

/// Provider for user's inventory
final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  return await EconomyService().getInventory();
});

/// Provider for shop products catalog
final shopProductsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  return await EconomyService().getShopProducts();
});

/// Provider to check if a specific item is owned
final ownsItemProvider = FutureProvider.family<bool, String>((ref, itemId) async {
  final inventory = await ref.watch(inventoryProvider.future);
  return inventory.any((item) => item.itemId == itemId);
});

/// Simple state provider for locally tracking pending coin rewards
/// (used to show "+X coins" animation before server confirms)
final pendingCoinsProvider = StateProvider<int>((ref) => 0);

/// Provider for transaction history
final transactionHistoryProvider = FutureProvider<List<EconomyTransaction>>((ref) async {
  return await EconomyService().getTransactionHistory();
});

/// Provider for currently selected card back
final selectedCardBackProvider = FutureProvider<String>((ref) async {
  return await EconomyService().getSelectedCardBack();
});
