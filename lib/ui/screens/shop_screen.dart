/// Shop screen for Nertz Royale
/// Browse and purchase cosmetic items with coins/gems

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/economy.dart';
import '../../services/economy_service.dart';
import '../../state/economy_provider.dart';
import '../theme/game_theme.dart';
import '../widgets/currency_display.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(shopProductsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final balanceAsync = ref.watch(balanceProvider);
    
    return Scaffold(
      backgroundColor: GameTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GameTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shop',
          style: TextStyle(
            color: GameTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CurrencyDisplay(compact: true),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) => inventoryAsync.when(
          data: (inventory) => balanceAsync.when(
            data: (balance) => _buildCardBacksList(
              products.where((p) => p.category == 'card_back').toList(),
              inventory,
              balance,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading balance')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading inventory')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading products')),
      ),
    );
  }
  
  Widget _buildCardBacksList(
    List<ShopProduct> products,
    List<InventoryItem> inventory,
    CurrencyBalance? balance,
  ) {
    // Group products by style
    final classicProducts = products.where((p) => p.id.contains('classic')).toList();
    final hippieProducts = products.where((p) => p.id.contains('hippie')).toList();
    final medievalProducts = products.where((p) => p.id.contains('medieval')).toList();
    final swampProducts = products.where((p) => p.id.contains('swamp')).toList();
    final wizardProducts = products.where((p) => p.id.contains('wizard')).toList();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (classicProducts.isNotEmpty) ...[
          _buildStyleSection('Classic', classicProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (hippieProducts.isNotEmpty) ...[
          _buildStyleSection('Hippie', hippieProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (medievalProducts.isNotEmpty) ...[
          _buildStyleSection('Medieval', medievalProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (swampProducts.isNotEmpty) ...[
          _buildStyleSection('Swamp', swampProducts, inventory, balance),
          const SizedBox(height: 24),
        ],
        if (wizardProducts.isNotEmpty) ...[
          _buildStyleSection('Wizard', wizardProducts, inventory, balance),
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
    
    // Determine currency to use (prefer coins if available)
    final useGems = product.priceCoins == 0 && product.priceGems > 0;
    final price = useGems ? product.priceGems : product.priceCoins;
    final currency = useGems ? 'gems' : 'coins';
    final currentBalance = useGems ? balance.gems : balance.coins;
    
    if (currentBalance < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough $currency!'),
          backgroundColor: GameTheme.error,
        ),
      );
      return;
    }
    
    // Confirm purchase
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Purchase ${product.name}?', style: const TextStyle(color: GameTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
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
                child: Image.asset(
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
