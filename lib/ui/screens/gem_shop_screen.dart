/// Gem Shop Screen
/// 
/// In-App Purchase screen for gems and coins:
/// - Individual gem purchases
/// - Bundle packages
/// - Apple Pay integration (future)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:in_app_purchase/in_app_purchase.dart';
import '../theme/game_theme.dart';
import '../widgets/currency_display.dart';
import '../../services/iap_service.dart';
import '../widgets/bounceable.dart';

class GemShopScreen extends ConsumerStatefulWidget {
  const GemShopScreen({super.key});

  @override
  ConsumerState<GemShopScreen> createState() => _GemShopScreenState();
}

class _GemShopScreenState extends ConsumerState<GemShopScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh products on load
    ref.read(iapServiceProvider).loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final iapService = ref.watch(iapServiceProvider);
    
    return Scaffold(
      backgroundColor: GameTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Gem Shop',
          style: TextStyle(
            color: GameTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GameTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current balance
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text(
                    'Your Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  CurrencyDisplay(compact: false, large: true, lightMode: true),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Products List (StreamBuilder)
            StreamBuilder<List<ProductDetails>>(
              stream: iapService.productsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final products = snapshot.data!;
                if (products.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Connecting to Store... (Verify IDs in valid list)'),
                    ),
                  );
                }

                // Categorize
                final gemProducts = products.where((p) => p.id.startsWith('gems_pack')).toList();
                final bundles = products.where((p) => p.id.startsWith('bundle')).toList();
                
                // Sort by price
                gemProducts.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gems section
                    if (gemProducts.isNotEmpty) ...[
                      const Text('GEMS', style: GameTheme.label),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: gemProducts.length,
                        itemBuilder: (context, index) {
                          final product = gemProducts[index];
                          // Determine metadata based on ID
                          final isPopular = product.id.contains('medium');
                          final isBonus = product.id.contains('large') || product.id.contains('huge');
                          
                          return _buildProductCard(
                            product: product,
                            isGem: true,
                            popular: isPopular,
                            bonus: isBonus,
                            onTap: () => iapService.buyProduct(product),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Bundles section
                    if (bundles.isNotEmpty) ...[
                      const Text('BUNDLES', style: GameTheme.label),
                      const SizedBox(height: 12),
                      ...bundles.map((product) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProductCard(
                          product: product,
                          isGem: false,
                          bestValue: true,
                          color: const Color(0xFFF59E0B),
                          onTap: () => iapService.buyProduct(product),
                        ),
                      )),
                    ],
                  ],
                );
              },
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required ProductDetails product,
    required bool isGem,
    required VoidCallback onTap,
    bool popular = false,
    bool bonus = false,
    bool bestValue = false,
    Color color = const Color(0xFF8B5CF6), // Default purple
  }) {
    // Extract numbers from title/description if needed, or use ID map
    int gemAmount = 0;
    int coinAmount = 0;
    
    // Pricing Logic Update
    if (isGem) {
      if (product.id.contains('small')) gemAmount = 5;
      else if (product.id.contains('medium')) gemAmount = 20; // $2.99
      else if (product.id.contains('large')) gemAmount = 50; // $5.99
      else if (product.id.contains('huge')) gemAmount = 250; // $19.99
    } else {
      // Bundle Logic
      // Assuming IDs contain price hint or ordered, but for now map based on approximate price text or ID
      // If we can't rely on price parsing, we rely on IDs.
      // Let's assume standard IDs for now or fallback logic.
      if (product.price.contains('2.99') || product.id.contains('starter')) {
        gemAmount = 15;
        coinAmount = 1500;
      } else if (product.price.contains('10.99') || product.id.contains('pro')) {
        gemAmount = 100;
        coinAmount = 2000;
      } else if (product.price.contains('29.99') || product.id.contains('ultimate')) {
        gemAmount = 350;
        coinAmount = 5000;
      }
    }
    
    // For bundle
    if (!isGem) {
      color = const Color(0xFF10B981); // Green for starter
    }

    if (isGem) {
      // Grid Card Style (Unchanged mostly, just amounts)
      return Bounceable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: popular ? color : GameTheme.glassBorder,
              width: popular ? 2 : 1,
            ),
            boxShadow: GameTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (popular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                const Spacer(),
                Icon(
                  Icons.diamond,
                  size: 36,
                  color: color,
                ),
                const SizedBox(height: 8),
                Text(
                  '$gemAmount',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.textPrimary,
                  ),
                ),
                if (bonus) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GameTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '+BONUS',
                      style: TextStyle(color: GameTheme.success, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: GameTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.price,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // List Tile Style (Bundle) - FIX OVERLAP HERE
      return Bounceable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: bestValue ? color : GameTheme.glassBorder,
              width: bestValue ? 2 : 1,
            ),
            boxShadow: GameTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.card_giftcard, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                
                // Expanded Section for Title/Desc
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row for Title + Badge
                      Wrap( // Use Wrap instead of Row to handle overflow gracefully if really needed, or just Row
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            product.title.replaceAll(RegExp(r'\(.*\)'), '').trim(), // Clean title
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: GameTheme.textPrimary,
                            ),
                          ),
                          if (bestValue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Custom Bundle Description based on our logic
                      Text(
                        '$coinAmount Coins + $gemAmount Gems',
                        style: const TextStyle(
                          color: GameTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Price Button
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Smaller padding
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13, // Smaller font size as requested
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
