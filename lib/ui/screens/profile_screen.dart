// import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nertz_royale/services/supabase_service.dart';

import 'package:nertz_royale/ui/theme/game_theme.dart';
import 'leaderboard_screen.dart';
import 'customization_screen.dart';

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
    final streak = (_profile!['win_streak'] as int?) ?? 0;
    final bestTime = _profile!['best_time'] as int?;
    
    // XP Logic
    final xp = (_profile!['total_xp'] as int?) ?? 0;
    
    // Ranks
    // Bronze: 0-249 XP
    // Silver: 250-999 XP
    // Gold: 1000-4999 XP
    // Platinum: 5000+ XP
    String rank = 'Bronze';
    String trophyAsset = 'assets/trophies/bronze.png';
    int nextLevelXp = 250;
    int currentLevelBaseXp = 0;
    Color ringColor = const Color(0xFFCD7F32); // Bronze
    
    if (xp >= 150000) {
      rank = 'Legend';
      trophyAsset = 'assets/trophies/legend.png';
      nextLevelXp = 1000000; // Max
      currentLevelBaseXp = 150000;
      ringColor = const Color(0xFFFFC107); // Amber/Gold
    } else if (xp >= 75000) {
      rank = 'Grandmaster';
      trophyAsset = 'assets/trophies/grandmaster.png';
      nextLevelXp = 150000;
      currentLevelBaseXp = 75000;
      ringColor = const Color(0xFFDC2626); // Red 600
    } else if (xp >= 25000) {
      rank = 'Master';
      trophyAsset = 'assets/trophies/master.png';
      nextLevelXp = 75000;
      currentLevelBaseXp = 25000;
      ringColor = const Color(0xFF9333EA); // Purple 600
    } else if (xp >= 10000) {
      rank = 'Diamond';
      trophyAsset = 'assets/trophies/diamond.png';
      nextLevelXp = 25000;
      currentLevelBaseXp = 10000;
      ringColor = const Color(0xFF0EA5E9); // Sky Blue 500
    } else if (xp >= 5000) {
      rank = 'Platinum';
      trophyAsset = 'assets/trophies/platinum.png';
      nextLevelXp = 10000;
      currentLevelBaseXp = 5000;
      ringColor = const Color(0xFFE5E4E2); // Platinum
    } else if (xp >= 1000) {
      rank = 'Gold';
      trophyAsset = 'assets/trophies/gold.png';
      nextLevelXp = 5000;
      currentLevelBaseXp = 1000;
      ringColor = const Color(0xFFFFD700); // Gold
    } else if (xp >= 250) {
      rank = 'Silver';
      trophyAsset = 'assets/trophies/silver.png';
      nextLevelXp = 1000;
      currentLevelBaseXp = 250;
      ringColor = const Color(0xFFC0C0C0); // Silver
    }
    
    final levelProgress = (xp - currentLevelBaseXp) / (nextLevelXp - currentLevelBaseXp);
    final isMaxLevel = xp >= 5000;

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
             // 1. Avatar & Level Ring & Gear
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 const SizedBox(width: 48), // Balance the gear on the right
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
                                : const AssetImage('assets/avatars/avatar1.jpg') as ImageProvider,
                            child: _isUploading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : null,
                         ),
                       ),
                     ),
                     
                     // Edit Pencil (Bottom Right of Avatar)
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
                 
                 // Customization Gear (Right of Avatar)
                 Padding(
                   padding: const EdgeInsets.only(left: 12, bottom: 12),
                   child: GestureDetector(
                     onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CustomizationScreen()),
                        );
                     },
                     child: Container(
                       width: 48,
                       height: 48,
                       decoration: BoxDecoration(
                         color: Colors.white,
                         shape: BoxShape.circle,
                         border: Border.all(color: GameTheme.primary, width: 2),
                         boxShadow: [
                           BoxShadow(
                             color: GameTheme.primary.withValues(alpha: 0.2),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           )
                         ],
                       ),
                       child: const Icon(Icons.settings, color: GameTheme.primary, size: 28),
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
                     child: GestureDetector(
                       onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LeaderboardScreen()),
                          );
                       },
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
                            const SizedBox(height: 8),
                            const Text(
                              "View Leaderboard",
                              style: TextStyle(
                                color: GameTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                         ],
                       ),
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
                   value: "$streak", 
                   icon: Icons.local_fire_department,
                   color: Colors.orange.shade50,
                   iconColor: Colors.orange,
                 ),
                 _buildStatCard(
                   title: "Cards Played",
                   value: "$xp",
                   icon: Icons.style, 
                   color: Colors.purple.shade50,
                   iconColor: Colors.purple,
                 ),
                 _buildStatCard(
                   title: "Best Time",
                   value: bestTime != null ? "${bestTime}s" : "--",
                   icon: Icons.bolt,
                   color: Colors.green.shade50,
                   iconColor: Colors.green,
                 ),
               ],
             ),
             
          ],
        ),
      ),
    );
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
