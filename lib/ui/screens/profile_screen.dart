// import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nertz_royale/services/supabase_service.dart';
import 'package:nertz_royale/services/matchmaking_service.dart'; // Added

import 'package:nertz_royale/ui/theme/game_theme.dart';
import 'package:nertz_royale/ui/widgets/bounceable.dart';
import 'leaderboard_screen.dart';
import 'customization_screen.dart';
import 'auth_gate.dart';

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
    
    // XP Logic & Thresholds
    final xp = (_profile!['total_xp'] as int?) ?? 0;
    
    // XP Rank Thresholds
    // Bronze: 0 - 500
    // Silver: 501 - 1500
    // Gold: 1501 - 2500
    // Platinum: 2501 - 5000
    // Master: 5001 - 10000
    // Legend: 10,001+
    
    String xpRankName;
    int currentRankMin;
    int nextRankMin;
    Color xpRankColor;
    
    if (xp <= 500) {
      xpRankName = 'Bronze';
      currentRankMin = 0;
      nextRankMin = 501;
      xpRankColor = const Color(0xFFCD7F32);
    } else if (xp <= 1500) {
      xpRankName = 'Silver';
      currentRankMin = 501;
      nextRankMin = 1501;
      xpRankColor = const Color(0xFFC0C0C0);
    } else if (xp <= 2500) {
      xpRankName = 'Gold';
      currentRankMin = 1501;
      nextRankMin = 2501;
      xpRankColor = const Color(0xFFFFD700);
    } else if (xp <= 5000) {
      xpRankName = 'Platinum';
      currentRankMin = 2501;
      nextRankMin = 5001;
      xpRankColor = const Color(0xFFE5E4E2);
    } else if (xp <= 10000) {
      xpRankName = 'Master';
      currentRankMin = 5001;
      nextRankMin = 10001;
      xpRankColor = const Color(0xFF9400D3); // Purple
    } else {
      xpRankName = 'Legend';
      currentRankMin = 10001;
      nextRankMin = 10001; // Max
      xpRankColor = const Color(0xFFFF4500); // Orange Red
    }
    
    final isMaxRank = xpRankName == 'Legend';
    
    // Calculate Progress Bar (0.0 to 1.0) within current tier
    double xpProgress = 0.0;
    if (!isMaxRank) {
      final range = nextRankMin - currentRankMin;
      final current = xp - currentRankMin;
      xpProgress = (current / range).clamp(0.0, 1.0);
    } else {
      xpProgress = 1.0;
    }

    // Ranked Logic (Competitive RP)
    final rankedPoints = (_profile!['ranked_points'] as int?) ?? 1000;
    final rankTier = RankTier.fromPoints(rankedPoints);
    
    // Use Rank for display
    String competitiveRank = rankTier.label;
    Color ringColor = rankTier.color;
    // TODO: Use real assets for ranks if available, fallback to existing or generic
    // Using existing trophy assets mapped to new tiers
    String trophyAsset = 'assets/trophies/${competitiveRank.toLowerCase()}.png';
    
    return Scaffold(
      backgroundColor: GameTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Removed back button per request
        title: const Text("Profile", style: TextStyle(color: GameTheme.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
       actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: GameTheme.error),
            tooltip: 'Sign Out',
            onPressed: () async {
               final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
                    ],
                  ),
               );
               
               if (confirm == true) {
                 await SupabaseService().signOut();
                 if (mounted) {
                   Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                      (route) => false,
                   );
                 }
               }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
                         value: xpProgress,
                         strokeWidth: 6,
                         backgroundColor: Colors.grey.shade200,
                         valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                         strokeCap: StrokeCap.round,
                       ),
                     ),
                     
                     // Avatar
                     Bounceable(
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
                       child: Bounceable(
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
                   child: Bounceable(
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
             Text('@$username • Rank: $competitiveRank', style: GameTheme.bodyMedium),
             
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
                        Text("XP Progress ($xpRankName)", style: GameTheme.label),
                        Text(
                          isMaxRank ? "$xp XP" : "$xp / $nextRankMin XP", 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: GameTheme.primary)
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        minHeight: 12,
                        backgroundColor: GameTheme.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(xpRankColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                       isMaxRank 
                         ? "You are a Nertz Legend!" 
                         : "${nextRankMin - xp} XP to reach ${
                              xpRankName == 'Bronze' ? 'Silver' :
                              xpRankName == 'Silver' ? 'Gold' :
                              xpRankName == 'Gold' ? 'Platinum' :
                              xpRankName == 'Platinum' ? 'Master' :
                              'Legend'
                           }",
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
                              '${competitiveRank.toUpperCase()} ${rankTier.getSubRank(rankedPoints)}',
                              style: TextStyle(
                                color: ringColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 2.0,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Points Display
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: ringColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: ringColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events, size: 16, color: ringColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$rankedPoints Points',
                                    style: TextStyle(
                                      color: ringColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
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
              
              const SizedBox(height: 40),
              
              // Sign Out Button
              Bounceable(
                onTap: () async {
                  await _service.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 48), // Bottom padding for scroll
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
