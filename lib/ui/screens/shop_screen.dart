/// Shop screen for Nertz Royale
/// Browse and purchase cosmetic items with coins/gems

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/economy.dart';
import '../../services/economy_service.dart';
import '../../state/economy_provider.dart';
import '../theme/game_theme.dart';
import '../widgets/currency_display.dart';

import 'package:cached_network_image/cached_network_image.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String _selectedCategory = 'card_back';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(shopProductsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final balanceAsync = ref.watch(balanceProvider);
    
    return Scaffold(
      backgroundColor: GameTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false, // No back button for main tab
        elevation: 0,
        leading: null,
        title: const Text(
          'Shop',
          style: TextStyle(
            color: GameTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),

      ),
      body: Column(
        children: [
          // Category Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCategoryTab('Cards', 'card_back', Icons.style),
                _buildCategoryTab('Music', 'music', Icons.music_note),
                _buildCategoryTab('Boards', 'board', Icons.table_restaurant),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: productsAsync.when(
              data: (products) => inventoryAsync.when(
                data: (inventory) => balanceAsync.when(
                  data: (balance) {
                    final filteredProducts = products.where((p) => p.category == _selectedCategory).toList();
                    
                    if (filteredProducts.isEmpty) {
                      return _buildEmptyState(_selectedCategory);
                    }
                    
                    if (_selectedCategory == 'card_back') {
                      return _buildCardBacksList(filteredProducts, inventory, balance);
                    } else if (_selectedCategory == 'music') {
                      return _buildMusicList(filteredProducts, inventory, balance);
                    } else if (_selectedCategory == 'board') {
                      // Reuse card back list style for now as they are visual items too
                      return _buildCardBacksList(filteredProducts, inventory, balance);
                    }
                    
                    // Fallback for other categories if they have items but no specific layout yet
                    return const Center(child: Text("Items available but no layout defined yet."));
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Error loading balance')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading inventory')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading products')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, String categoryId, IconData icon) {
    final isSelected = _selectedCategory == categoryId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = categoryId),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? GameTheme.primary : Colors.grey.shade100,
              shape: BoxShape.circle,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: GameTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? GameTheme.primary : Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    IconData icon;
    String message;
    
    switch (category) {
      case 'board':
        icon = Icons.table_restaurant;
        message = "Custom game boards coming soon!";
        break;
      default:
        icon = Icons.inventory_2;
        message = "No items available yet.";
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "STAY TUNED",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicList(
    List<ShopProduct> products,
    List<InventoryItem> inventory,
    CurrencyBalance? balance,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOwned = inventory.any((i) => i.itemId == product.id) || product.isFree;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GameTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note, color: GameTheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: GameTheme.textPrimary,
                      ),
                    ),
                    Text(
                      product.description ?? 'Awesome track',
                      style: const TextStyle(
                        color: GameTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action
              if (isOwned)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.check_circle, color: GameTheme.success),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => _handlePurchase(product, balance),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/coin_icon.png', width: 16, height: 16),
                      const SizedBox(width: 4),
                      Text('${product.priceCoins}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCardBacksList(
    List<ShopProduct> products,
    List<InventoryItem> inventory,
    CurrencyBalance? balance,
  ) {
    // Group products by rarity (based on coin price)
    final commonProducts = products.where((p) => p.priceCoins <= 150).toList();
    final uncommonProducts = products.where((p) => p.priceCoins > 150 && p.priceCoins <= 300).toList();
    final rareProducts = products.where((p) => p.priceCoins > 300 && p.priceCoins <= 750).toList();
    final ultraRareProducts = products.where((p) => p.priceCoins > 750 && p.priceCoins <= 4999).toList();
    final legendaryProducts = products.where((p) => p.priceCoins > 4999).toList();
    
    // Sort logic within groups if needed? Assuming DB sort_order is fine, or maybe sort by price ascending?
    // Let's keep them in the order they came from the DB (likely default sort) for now.

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (commonProducts.isNotEmpty) ...[
          _buildStyleSection('Common', commonProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (uncommonProducts.isNotEmpty) ...[
          _buildStyleSection('Uncommon', uncommonProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (rareProducts.isNotEmpty) ...[
          _buildStyleSection('Rare', rareProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (ultraRareProducts.isNotEmpty) ...[
          _buildStyleSection('Ultra-Rare', ultraRareProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (legendaryProducts.isNotEmpty) ...[
          _buildStyleSection('Legendary ★', legendaryProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
  
  Widget _buildStyleSection(
    String styleName,
    List<ShopProduct> products,
    List<InventoryItem> inventory,
    CurrencyBalance? balance,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          styleName.toUpperCase(),
          style: const TextStyle(
            color: GameTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final isOwned = inventory.any((i) => i.itemId == product.id) || product.isFree;
              return Padding(
                padding: EdgeInsets.only(right: index < products.length - 1 ? 12 : 0),
                child: _CardBackItem(
                  product: product,
                  isOwned: isOwned,
                  balance: balance,
                  onPurchase: () => _handlePurchase(product, balance),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Future<void> _handlePurchase(ShopProduct product, CurrencyBalance? balance) async {
    if (balance == null) return;
    
    // Check which payment options are available
    final canPayWithCoins = product.priceCoins > 0 && balance.coins >= product.priceCoins;
    final canPayWithGems = product.priceGems > 0 && balance.gems >= product.priceGems;
    
    // If user can't afford with either currency
    if (!canPayWithCoins && !canPayWithGems) {
      String message;
      if (product.priceCoins > 0 && product.priceGems > 0) {
        message = 'Not enough coins or gems!';
      } else if (product.priceCoins > 0) {
        message = 'Not enough coins!';
      } else {
        message = 'Not enough gems!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: GameTheme.error,
        ),
      );
      return;
    }
    
    // Determine which currency to use
    String currency;
    int price;
    
    // If both payment options are available, show picker
    if (canPayWithCoins && canPayWithGems) {
      final selectedCurrency = await _showCurrencyPicker(product, balance);
      if (selectedCurrency == null) return; // User cancelled
      currency = selectedCurrency;
      price = currency == 'coins' ? product.priceCoins : product.priceGems;
    } else if (canPayWithCoins) {
      currency = 'coins';
      price = product.priceCoins;
    } else {
      currency = 'gems';
      price = product.priceGems;
    }
    
    // Confirm purchase
    final confirmed = await _showPurchaseConfirmation(product, currency, price);
    if (confirmed != true) return;
    
    // Execute purchase
    final success = await EconomyService().purchaseItem(
      itemId: product.id,
      currency: currency,
      price: price,
    );
    
    if (success) {
      ref.invalidate(balanceProvider);
      ref.invalidate(inventoryProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchased ${product.name}! 🎉'),
            backgroundColor: GameTheme.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: GameTheme.error,
          ),
        );
      }
    }
  }
  
  /// Shows a popup for user to choose between coins or gems
  Future<String?> _showCurrencyPicker(ShopProduct product, CurrencyBalance balance) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Choose Payment',
          style: TextStyle(
            color: GameTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How would you like to pay?',
              style: TextStyle(
                color: GameTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Coins option
                _buildCurrencyOption(
                  ctx: ctx,
                  currency: 'coins',
                  iconPath: 'assets/coin_icon.png',
                  price: product.priceCoins,
                  currentBalance: balance.coins,
                  color: const Color(0xFFFFD700),
                ),
                // Gems option
                _buildCurrencyOption(
                  ctx: ctx,
                  currency: 'gems',
                  iconPath: 'assets/gem_icon.png',
                  price: product.priceGems,
                  currentBalance: balance.gems,
                  color: const Color(0xFF9B59B6),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrencyOption({
    required BuildContext ctx,
    required String currency,
    required String iconPath,
    required int price,
    required int currentBalance,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, currency),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Image.asset(iconPath, width: 48, height: 48),
            const SizedBox(height: 12),
            Text(
              '$price',
              style: TextStyle(
                color: GameTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Balance: $currentBalance',
              style: TextStyle(
                color: GameTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<bool?> _showPurchaseConfirmation(ShopProduct product, String currency, int price) {
    final useGems = currency == 'gems';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Purchase ${product.name}?', style: const TextStyle(color: GameTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview - Show icon for music, image for other products
            if (product.category == 'music')
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: GameTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.music_note, color: GameTheme.primary, size: 40),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  product.assetPath ?? 'assets/card_back.png',
                  width: 80,
                  height: 112,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  useGems ? 'assets/gem_icon.png' : 'assets/coin_icon.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '$price',
                  style: const TextStyle(
                    color: GameTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }
}

class _CardBackItem extends StatelessWidget {
  final ShopProduct product;
  final bool isOwned;
  final CurrencyBalance? balance;
  final VoidCallback onPurchase;

  const _CardBackItem({
    required this.product,
    required this.isOwned,
    required this.balance,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final bal = balance;
    final canAffordCoins = bal != null && bal.coins >= product.priceCoins;
    final canAffordGems = bal != null && bal.gems >= product.priceGems;
    final canAfford = product.isFree || canAffordCoins || canAffordGems;
    
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwned 
              ? GameTheme.success.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: isOwned ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card image
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (product.assetPath != null && product.assetPath!.startsWith('http'))
                    ? CachedNetworkImage(
                        imageUrl: product.assetPath!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                      )
                    : Image.asset(
                        product.assetPath ?? 'assets/card_back.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          
          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              product.name,
              style: const TextStyle(
                color: GameTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Price or Owned
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: isOwned
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: GameTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        '✓ Owned',
                        style: TextStyle(
                          color: GameTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: canAfford ? onPurchase : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: canAfford ? GameTheme.primaryGradient : null,
                        color: canAfford ? null : Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Coins price
                          if (product.priceCoins > 0) ...[
                            Image.asset('assets/coin_icon.png', width: 14, height: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${product.priceCoins}',
                              style: TextStyle(
                                color: canAfford ? Colors.white : GameTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (product.priceCoins > 0 && product.priceGems > 0)
                            Text(
                              ' / ',
                              style: TextStyle(
                                color: canAfford ? Colors.white70 : GameTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          // Gems price
                          if (product.priceGems > 0) ...[
                            Image.asset('assets/gem_icon.png', width: 14, height: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${product.priceGems}',
                              style: TextStyle(
                                color: canAfford ? Colors.white : GameTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
