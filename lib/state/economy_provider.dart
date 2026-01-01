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

/// Provider for currently selected card back ID
final selectedCardBackProvider = FutureProvider<String>((ref) async {
  return await EconomyService().getSelectedCardBack();
});

/// Provider for the full asset path/URL of the selected card back
/// This looks up the product in shop_products to get the cloud URL
final selectedCardBackAssetProvider = FutureProvider<String>((ref) async {
  final selectedId = await ref.watch(selectedCardBackProvider.future);
  final products = await ref.watch(shopProductsProvider.future);
  
  // Find the product with matching ID
  final product = products.cast<ShopProduct?>().firstWhere(
    (p) => p?.id == selectedId,
    orElse: () => null,
  );
  
  // Return the asset path from the product, or fallback to default
  if (product != null && product.assetPath != null) {
    return product.assetPath!;
  }
  
  // Fallback for default card back
  return 'assets/card_back.png';
});

/// Provider for currently selected music ID
final selectedMusicIdProvider = FutureProvider<String?>((ref) async {
  return await EconomyService().getSelectedMusicId();
});

/// Provider for the full asset path of the selected music
/// Note: Returns paths WITHOUT 'assets/' prefix since AudioService uses AssetSource which adds it
final selectedMusicAssetProvider = FutureProvider<String>((ref) async {
  final selectedId = await ref.watch(selectedMusicIdProvider.future);
  
  if (selectedId == null) {
    return 'audio/background.mp3'; // Default track (no prefix needed)
  }

  final products = await ref.watch(shopProductsProvider.future);
  
  // Find the product with matching ID
  final product = products.cast<ShopProduct?>().firstWhere(
    (p) => p?.id == selectedId,
    orElse: () => null,
  );
  
  // Return the asset path from the product, or fallback to default
  if (product != null && product.assetPath != null) {
    // Strip 'assets/' prefix if present (AssetSource adds it automatically)
    String path = product.assetPath!;
    if (path.startsWith('assets/')) {
      path = path.substring(7); // Remove 'assets/' prefix
    }
    return path;
  }
  
  return 'audio/background.mp3';
});

/// Provider for currently selected background ID
final selectedBackgroundIdProvider = FutureProvider<String?>((ref) async {
  return await EconomyService().getSelectedBackgroundId();
});

/// Provider for the full asset path of the selected background
/// Returns null if no background is selected (use default theme color)
final selectedBackgroundAssetProvider = FutureProvider<String?>((ref) async {
  final selectedId = await ref.watch(selectedBackgroundIdProvider.future);
  
  if (selectedId == null) {
    return null; // No custom background
  }

  final products = await ref.watch(shopProductsProvider.future);
  
  // Find the product with matching ID
  final product = products.cast<ShopProduct?>().firstWhere(
    (p) => p?.id == selectedId,
    orElse: () => null,
  );
  
  // Return the asset path from the product
  if (product != null && product.assetPath != null) {
    return product.assetPath!;
  }
  
  return null;
});
