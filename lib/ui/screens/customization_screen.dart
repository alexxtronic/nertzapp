import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nertz_royale/models/economy.dart';
import 'package:nertz_royale/services/economy_service.dart';
import 'package:nertz_royale/state/economy_provider.dart';
import 'package:nertz_royale/ui/theme/game_theme.dart';

class CustomizationScreen extends ConsumerStatefulWidget {
  const CustomizationScreen({super.key});

  @override
  ConsumerState<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends ConsumerState<CustomizationScreen> {
  
  Future<void> _selectCardBack(String itemId) async {
    final success = await EconomyService().setSelectedCardBack(itemId);
    if (success) {
      ref.invalidate(selectedCardBackProvider);
      ref.invalidate(selectedCardBackAssetProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card back updated! 🎴'),
            backgroundColor: GameTheme.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _selectMusic(String? itemId) async {
    final success = await EconomyService().setSelectedMusicId(itemId);
    if (success) {
      ref.invalidate(selectedMusicIdProvider);
      ref.invalidate(selectedMusicAssetProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Soundtrack updated! 🎵'),
            backgroundColor: GameTheme.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _selectBackground(String? itemId) async {
    final success = await EconomyService().setSelectedBackgroundId(itemId);
    if (success) {
      ref.invalidate(selectedBackgroundIdProvider);
      ref.invalidate(selectedBackgroundAssetProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background updated! 🖼️'),
            backgroundColor: GameTheme.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: GameTheme.textPrimary),
        title: const Text("Customization", style: TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatars (Placeholder)
            _buildSectionHeader("Avatar", "Choose your look"),
            const SizedBox(height: 16),
            _buildPlaceholderSection("More avatars coming soon!", Icons.face),
            const SizedBox(height: 32),

            // 2. Card Backs (Migrated)
            _buildSectionHeader("Card Deck", "Select your card style"),
            const SizedBox(height: 16),
            _buildCardBackSelector(),
            const SizedBox(height: 32),
            
            // 3. Music (New)
            _buildSectionHeader("Soundtrack", "Set the vibe"),
            const SizedBox(height: 16),
            _buildMusicSelector(),
            const SizedBox(height: 32),

            // 4. Board Backgrounds (Placeholder)
            _buildSectionHeader("Game Board", "Customize your play area"),
            const SizedBox(height: 16),
            // 4. Board Backgrounds
            _buildSectionHeader("Game Board", "Customize your play area"),
            const SizedBox(height: 16),
            _buildBackgroundSelector(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GameTheme.h2),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: GameTheme.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildPlaceholderSection(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "COMING SOON",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a card back image widget that handles both cloud URLs and local assets
  Widget _buildCardBackImage(String? assetPath) {
    final path = assetPath ?? 'assets/card_back.png';
    
    // If it's a URL (from Supabase Storage), use CachedNetworkImage
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
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
        errorWidget: (context, url, error) => Image.asset(
          'assets/card_back.png',
          fit: BoxFit.cover,
        ),
      );
    }
    
    // Otherwise, load from local assets
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/card_back.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildCardBackSelector() {
    final inventoryAsync = ref.watch(inventoryProvider);
    final selectedAsync = ref.watch(selectedCardBackProvider);
    final productsAsync = ref.watch(shopProductsProvider);
    
    return productsAsync.when(
      data: (products) => inventoryAsync.when(
        data: (inventory) => selectedAsync.when(
          data: (selectedId) {
            // Get owned card backs (including default)
            final ownedIds = inventory.map((i) => i.itemId).toSet();
            ownedIds.add('card_back_classic_default'); // Default is always owned
            
            final ownedProducts = products
                .where((p) => p.category == 'card_back' && ownedIds.contains(p.id))
                .toList();
            
            // Also add default if not in products
            if (!ownedProducts.any((p) => p.id == 'card_back_classic_default')) {
              ownedProducts.insert(0, ShopProduct(
                id: 'card_back_classic_default',
                name: 'Classic Red',
                category: 'card_back',
                priceCoins: 0,
                priceGems: 0,
                assetPath: 'assets/card_back.png',
              ));
            }
            
            if (ownedProducts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "No card backs owned yet.\nVisit the shop to purchase some!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GameTheme.textSecondary),
                  ),
                ),
              );
            }
            
            return SizedBox(
              height: 180, // Slightly taller for better spacing
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ownedProducts.length,
                itemBuilder: (context, index) {
                  final product = ownedProducts[index];
                  final isSelected = product.id == selectedId;
                  
                  return GestureDetector(
                    onTap: () => _selectCardBack(product.id),
                    child: Container(
                      width: 110, // Wider for better touch target
                      margin: EdgeInsets.only(right: index < ownedProducts.length - 1 ? 16 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? GameTheme.primary : Colors.grey.shade200,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: GameTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ] : [
                           BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildCardBackImage(product.assetPath),
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? GameTheme.primary : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(13),
                                bottomRight: Radius.circular(13),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : GameTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isSelected)
                                  const Text(
                                    "EQUIPPED",
                                    style: TextStyle(
                                      color: Colors.white, 
                                      fontSize: 9, 
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildMusicSelector() {
    final inventoryAsync = ref.watch(inventoryProvider);
    final selectedAsync = ref.watch(selectedMusicIdProvider);
    final productsAsync = ref.watch(shopProductsProvider);

    return productsAsync.when(
      data: (products) => inventoryAsync.when(
        data: (inventory) => selectedAsync.when(
          data: (selectedId) {
            // Filter owned music
            final ownedIds = inventory.map((i) => i.itemId).toSet();
            
            final ownedMusic = products
                .where((p) => p.category == 'music' && ownedIds.contains(p.id))
                .toList();

            // Always add default track
            // Check if default is already in ownedMusic? No, it's not a shop product usually.
            // But if we want to treat it as one for selection UI:
            final defaultTrack = ShopProduct(
              id: 'music_default', // Use null or specific ID for default?
              // Ideally null means default in DB? Or 'music_default'?
              // Let's assume nullable ID = default. Or specific ID 'music_default'
              // The DB has nullable selected_music_id. If null -> default.
              // So for selection, let's represent Default as a product.
              name: 'Default Grooves',
              category: 'music',
              priceCoins: 0,
              priceGems: 0,
              assetPath: 'audio/background.mp3',
              description: 'The classic Nertz Royale beat.',
            );

            // Insert default at start
            final allTracks = [defaultTrack, ...ownedMusic];

            return Column(
              children: allTracks.map((track) {
                // If track.id is 'music_default', we treat it as selected if selectedId is null
                // Or if selectedId == 'music_default' (if we decide to store it that way)
                // For now, let's say null = default.
                final isDefault = track.id == 'music_default';
                final isSelected = (selectedId == null && isDefault) || (selectedId == track.id);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _selectMusic(isDefault ? null : track.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? GameTheme.primary : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? GameTheme.primary : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected ? Icons.music_note : Icons.play_arrow_rounded,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? GameTheme.primary : GameTheme.textPrimary,
                                  ),
                                ),
                                if (track.description != null)
                                  Text(
                                    track.description!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GameTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Text(
                              "PLAYING",
                              style: TextStyle(
                                color: GameTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error: $e')),
    );
  }
  Widget _buildBackgroundSelector() {
    final inventoryAsync = ref.watch(inventoryProvider);
    final selectedAsync = ref.watch(selectedBackgroundIdProvider);
    final productsAsync = ref.watch(shopProductsProvider);

    return productsAsync.when(
      data: (products) => inventoryAsync.when(
        data: (inventory) => selectedAsync.when(
          data: (selectedId) {
            // Filter owned backgrounds
            final ownedIds = inventory.map((i) => i.itemId).toSet();
            final ownedBackgrounds = products
                .where((p) => p.category == 'board' && ownedIds.contains(p.id))
                .toList();

            // Default Option
            final defaultOption = ShopProduct(
              id: 'bg_default', // Use special ID for selection logic
              name: 'Default',
              category: 'board',
              priceCoins: 0,
              priceGems: 0,
              assetPath: null, // No asset means default gradient
              description: 'Classic Nertz Royale theme',
            );
            
            final allBackgrounds = [defaultOption, ...ownedBackgrounds];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: allBackgrounds.length,
              itemBuilder: (context, index) {
                final product = allBackgrounds[index];
                final isDefault = product.id == 'bg_default';
                final isSelected = (selectedId == null && isDefault) || (selectedId == product.id);

                return GestureDetector(
                  onTap: () => _selectBackground(isDefault ? null : product.id),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? GameTheme.primary : Colors.grey.shade200,
                        width: isSelected ? 3 : 1,
                      ),
                      image: product.assetPath != null ? DecorationImage(
                        image: AssetImage(product.assetPath!),
                        fit: BoxFit.cover,
                      ) : null,
                      gradient: product.assetPath == null ? GameTheme.backgroundGradient : null,
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: GameTheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ] : null,
                    ),
                    child: Stack(
                      children: [
                        if (isSelected)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: GameTheme.primary, size: 20),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                            ),
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error: $e')),
    );
  }
}
