// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nertz_royale/models/player_state.dart' show PlayerRank;
import 'package:nertz_royale/services/supabase_service.dart';
import 'package:nertz_royale/services/economy_service.dart';
import 'package:nertz_royale/state/economy_provider.dart';
import 'package:nertz_royale/models/economy.dart';
import 'package:nertz_royale/ui/theme/game_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final SupabaseService _service = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    // Ensure we are signed in (anonymously or otherwise)
    if (_service.currentUser == null) {
      await _service.signInAnonymously();
    }
    
    final profile = await _service.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (image == null) return;

      setState(() => _isUploading = true);
      
      final downloadUrl = await _service.uploadAvatar(image);
      
      if (downloadUrl != null) {
        await _service.updateProfile(avatarUrl: downloadUrl);
        await _loadProfile(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showEditUsernameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: GameTheme.glassDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Edit Username ✏️', style: GameTheme.h2),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: GameTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Screen Name',
                        labelStyle: const TextStyle(color: GameTheme.textSecondary),
                        errorText: errorText,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: GameTheme.accent, width: 2),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Letters and numbers only. No spaces or special characters.',
                      style: TextStyle(color: GameTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL', style: TextStyle(color: GameTheme.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () async {
                            final newName = controller.text.trim();
                            if (newName == currentName) {
                              Navigator.pop(context);
                              return;
                            }
                            if (newName.length < 3) {
                              setState(() => errorText = 'Minimum 3 characters');
                              return;
                            }

                            // Check availability
                            final isAvailable = await _service.isUsernameAvailable(newName);
                            if (!isAvailable) {
                              setState(() => errorText = 'That name is taken');
                              return;
                            }

                            try {
                              Navigator.pop(context); // Close dialog
                              await _service.updateProfile(username: newName);
                              await _loadProfile();
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Username updated!'),
                                    backgroundColor: GameTheme.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Update failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('SAVE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              

            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final username = _profile!['username'] as String? ?? 'Player';
    final avatarUrl = _profile!['avatar_url'] as String?;
    final wins = (_profile!['wins'] as int?) ?? 0;
    
    // XP Logic
    // 10 XP per win
    final xp = wins * 10;
    
    // Ranks
    // Bronze: 0-99 XP
    // Silver: 100-249 XP
    // Gold: 250-499 XP
    // Platinum: 500+ XP
    String rank = 'Bronze';
    String trophyAsset = 'assets/trophies/bronze.png';
    int nextLevelXp = 100;
    int currentLevelBaseXp = 0;
    Color ringColor = const Color(0xFFCD7F32); // Bronze
    
    if (xp >= 500) {
      rank = 'Platinum';
      trophyAsset = 'assets/trophies/platinum.png';
      nextLevelXp = 10000; // Max
      currentLevelBaseXp = 500;
      ringColor = const Color(0xFFE5E4E2); // Platinum
    } else if (xp >= 250) {
      rank = 'Gold';
      trophyAsset = 'assets/trophies/gold.png';
      nextLevelXp = 500;
      currentLevelBaseXp = 250;
      ringColor = const Color(0xFFFFD700); // Gold
    } else if (xp >= 100) {
      rank = 'Silver';
      trophyAsset = 'assets/trophies/silver.png';
      nextLevelXp = 250;
      currentLevelBaseXp = 100;
      ringColor = const Color(0xFFC0C0C0); // Silver
    }
    
    final levelProgress = (xp - currentLevelBaseXp) / (nextLevelXp - currentLevelBaseXp);
    final isMaxLevel = xp >= 500;

    return Scaffold(
      backgroundColor: GameTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: GameTheme.textPrimary),
        title: const Text("Profile", style: TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. Avatar & Level Ring
             Stack(
               alignment: Alignment.center,
               children: [
                 // Progress Ring
                 SizedBox(
                   width: 130,
                   height: 130,
                   child: CircularProgressIndicator(
                     value: isMaxLevel ? 1.0 : levelProgress,
                     strokeWidth: 6,
                     backgroundColor: Colors.grey.shade200,
                     valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                     strokeCap: StrokeCap.round,
                   ),
                 ),
                 
                 // Avatar
                 GestureDetector(
                   onTap: _pickAndUploadImage,
                   child: Container(
                     width: 110,
                     height: 110,
                     decoration: const BoxDecoration(
                       shape: BoxShape.circle,
                       color: Colors.white,
                     ),
                     padding: const EdgeInsets.all(4), 
                     child: CircleAvatar(
                        backgroundColor: GameTheme.primary,
                        backgroundImage: avatarUrl != null 
                            ? NetworkImage(avatarUrl) 
                            : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                        child: _isUploading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : null,
                     ),
                   ),
                 ),
                 
                 // Edit Pencil
                 Positioned(
                   bottom: 0,
                   right: 0,
                   child: GestureDetector(
                     onTap: _pickAndUploadImage,
                     child: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: GameTheme.primary,
                         shape: BoxShape.circle,
                         border: Border.all(color: Colors.white, width: 2),
                         boxShadow: GameTheme.softShadow,
                       ),
                       child: const Icon(Icons.edit, color: Colors.white, size: 16),
                     ),
                   ),
                 ),
               ],
             ),
             
             const SizedBox(height: 16),
             
             // 2. Name & Handle
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  Text(username, style: GameTheme.h2),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: GameTheme.textSecondary),
                    onPressed: () => _showEditUsernameDialog(username),
                  ),
               ],
             ),
             Text('@$username • Rank: $rank', style: GameTheme.bodyMedium),
             
             const SizedBox(height: 32),
             
             // 3. XP Bar
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(16),
                 boxShadow: GameTheme.softShadow,
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text("XP Progress", style: GameTheme.label),
                       Text(isMaxLevel ? "MAX LEVEL" : "$xp / $nextLevelXp XP", style: const TextStyle(fontWeight: FontWeight.bold, color: GameTheme.primary)),
                     ],
                   ),
                   const SizedBox(height: 12),
                   ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: LinearProgressIndicator(
                       value: isMaxLevel ? 1.0 : levelProgress,
                       minHeight: 12,
                       backgroundColor: GameTheme.surfaceLight,
                       valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                      isMaxLevel 
                        ? "You are a Nertz Legend!" 
                        : "${nextLevelXp - xp} XP to reach ${rank == 'Bronze' ? 'Silver' : (rank == 'Silver' ? 'Gold' : 'Platinum')}",
                      style: const TextStyle(fontSize: 12, color: GameTheme.textSecondary),
                   ),
                   
                   const SizedBox(height: 24),
             
                   // Rank Display - Glowing Circle
                   Center(
                     child: Column(
                       children: [
                          Text(
                            rank.toUpperCase(), 
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: 1.2,
                              color: GameTheme.textPrimary
                            )
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: ringColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: ringColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  1.3, 0, 0, 0, 0,
                                  0, 1.3, 0, 0, 0,
                                  0, 0, 1.3, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                                child: Image.asset(trophyAsset, width: 100, height: 100, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             
             const SizedBox(height: 24),
             
             // 4. Stats Grid
             const Align(alignment: Alignment.centerLeft, child: Text("Game Statistics", style: GameTheme.h2)),
             const SizedBox(height: 16),
             
             GridView.count(
               crossAxisCount: 2,
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               mainAxisSpacing: 16,
               crossAxisSpacing: 16,
               childAspectRatio: 1.1,
               children: [
                  _buildStatCard(
                    title: "Total Wins",
                    value: "$wins",
                    emoji: "#",
                    color: Colors.blue.shade50,
                  ),
                 _buildStatCard(
                   title: "Win Streak",
                   value: "${wins > 0 ? 1 : 0}", 
                   icon: Icons.local_fire_department,
                   color: Colors.orange.shade50,
                   iconColor: Colors.orange,
                 ),
                 _buildStatCard(
                   title: "Cards Played",
                   value: "${wins * 98}",
                   icon: Icons.style, 
                   color: Colors.purple.shade50,
                   iconColor: Colors.purple,
                 ),
                 _buildStatCard(
                   title: "Best Time",
                   value: wins > 0 ? "45s" : "--",
                   icon: Icons.bolt,
                   color: Colors.green.shade50,
                   iconColor: Colors.green,
                 ),
               ],
             ),
             
             const SizedBox(height: 32),
             
             // 5. Customize Cards Section
             const Align(alignment: Alignment.centerLeft, child: Text("Customize Cards", style: GameTheme.h2)),
             const SizedBox(height: 8),
             const Text(
               "Select a card back for your deck",
               style: TextStyle(color: GameTheme.textSecondary, fontSize: 14),
             ),
             const SizedBox(height: 16),
             _buildCardBackSelector(),
          ],
        ),
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
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ownedProducts.length,
                itemBuilder: (context, index) {
                  final product = ownedProducts[index];
                  final isSelected = product.id == selectedId;
                  
                  return GestureDetector(
                    onTap: () => _selectCardBack(product.id),
                    child: Container(
                      width: 100,
                      margin: EdgeInsets.only(right: index < ownedProducts.length - 1 ? 12 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? GameTheme.primary : Colors.grey.shade200,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: GameTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ] : null,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  EconomyService.getCardBackAssetPath(product.id),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: const BoxDecoration(
                                color: GameTheme.primary,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'EQUIPPED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          error: (_, __) => const Text('Error loading selection'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Text('Error loading inventory'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading products'),
    );
  }
  
  Future<void> _selectCardBack(String itemId) async {
    final success = await EconomyService().setSelectedCardBack(itemId);
    if (success) {
      ref.invalidate(selectedCardBackProvider);
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

  Widget _buildStatCard({
    required String title,
    required String value,
    IconData? icon,
    String? imageAsset,
    String? emoji,
    required Color color,
    Color iconColor = GameTheme.primary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: GameTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: emoji != null
                ? Text(emoji, style: const TextStyle(fontSize: 24))
                : (imageAsset != null 
                  ? Image.asset(imageAsset, width: 24, height: 24, errorBuilder: (_,__,___) => const Icon(Icons.emoji_events, color: Colors.amber))
                  : Icon(icon, color: iconColor, size: 24)),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: GameTheme.textPrimary)),
              Text(title, style: GameTheme.label),
            ],
          ),
        ],
      ),
    );

  }
}
