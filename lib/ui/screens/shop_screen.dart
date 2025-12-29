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

class _ShopScreenState extends ConsumerState<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ['Card Backs', 'Avatars', 'Sounds'];
  final List<String> _categoryKeys = ['card_back', 'avatar', 'sound'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(shopProductsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final balanceAsync = ref.watch(balanceProvider);
    
    return Scaffold(
      backgroundColor: GameTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GameTheme.primary,
          labelColor: GameTheme.primary,
          unselectedLabelColor: GameTheme.textSecondary,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: productsAsync.when(
        data: (products) => inventoryAsync.when(
          data: (inventory) => balanceAsync.when(
            data: (balance) => TabBarView(
              controller: _tabController,
              children: _categoryKeys.map((category) {
                final categoryProducts = products
                    .where((p) => p.category == category)
                    .toList();
                return _buildProductGrid(categoryProducts, inventory, balance);
              }).toList(),
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
  
  Widget _buildProductGrid(
    List<ShopProduct> products,
    List<InventoryItem> inventory,
    CurrencyBalance? balance,
  ) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: GameTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Coming Soon!', style: TextStyle(color: GameTheme.textSecondary, fontSize: 18)),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOwned = inventory.any((i) => i.itemId == product.id);
        return _ShopItemCard(
          product: product,
          isOwned: isOwned,
          balance: balance,
          onPurchase: () => _handlePurchase(product, balance),
        );
      },
    );
  }
  
  Future<void> _handlePurchase(ShopProduct product, CurrencyBalance? balance) async {
    if (balance == null) return;
    
    // Determine currency to use
    final useGems = product.priceGems > 0 && product.priceCoins == 0;
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
        backgroundColor: GameTheme.surface,
        title: Text('Purchase ${product.name}?', style: const TextStyle(color: GameTheme.textPrimary)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cost: ', style: TextStyle(color: GameTheme.textSecondary)),
            Image.asset(
              useGems ? 'assets/gem_icon.png' : 'assets/coin_icon.png',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 4),
            Text('$price', style: const TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary),
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
      // Refresh providers
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

class _ShopItemCard extends StatelessWidget {
  final ShopProduct product;
  final bool isOwned;
  final CurrencyBalance? balance;
  final VoidCallback onPurchase;

  const _ShopItemCard({
    required this.product,
    required this.isOwned,
    required this.balance,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final useGems = product.priceGems > 0 && product.priceCoins == 0;
    final price = useGems ? product.priceGems : product.priceCoins;
    final bal = balance;
    final canAfford = bal != null && 
        (useGems ? bal.gems >= price : bal.coins >= price);
    
    return Container(
      decoration: BoxDecoration(
        color: GameTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwned 
              ? GameTheme.success.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isOwned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview area
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GameTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _buildPreview(),
              ),
            ),
          ),
          
          // Info section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              product.name,
              style: const TextStyle(
                color: GameTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Price / Owned badge
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: isOwned
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: GameTheme.success.withValues(alpha: 0.2),
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
                : product.isFree
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: GameTheme.textSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Default',
                            style: TextStyle(
                              color: GameTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: canAfford ? onPurchase : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: canAfford ? GameTheme.primaryGradient : null,
                            color: canAfford ? null : GameTheme.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                useGems ? 'assets/gem_icon.png' : 'assets/coin_icon.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$price',
                                style: TextStyle(
                                  color: canAfford ? Colors.white : GameTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreview() {
    // Show different preview based on category
    switch (product.category) {
      case 'card_back':
        return Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            gradient: _getCardBackGradient(),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              'N',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)],
              ),
            ),
          ),
        );
      case 'avatar':
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _getAvatarGradient(),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        );
      case 'sound':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: GameTheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.music_note, color: GameTheme.primary, size: 24),
        );
      default:
        return const Icon(Icons.help_outline, color: GameTheme.textSecondary, size: 32);
    }
  }
  
  LinearGradient _getCardBackGradient() {
    switch (product.id) {
      case 'card_back_flames':
        return const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF0000)]);
      case 'card_back_ocean':
        return const LinearGradient(colors: [Color(0xFF0077B6), Color(0xFF00B4D8)]);
      case 'card_back_galaxy':
        return const LinearGradient(colors: [Color(0xFF7B2CBF), Color(0xFF3C096C)]);
      case 'card_back_gold':
        return const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);
      default:
        return GameTheme.primaryGradient;
    }
  }
  
  LinearGradient _getAvatarGradient() {
    switch (product.id) {
      case 'avatar_crown':
        return const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);
      case 'avatar_fire':
        return const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF0000)]);
      default:
        return GameTheme.primaryGradient;
    }
  }
}
