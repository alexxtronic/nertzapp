// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nertz_royale/models/player_state.dart' show PlayerRank;
import 'package:nertz_royale/services/supabase_service.dart';
import 'package:nertz_royale/ui/theme/game_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: GameTheme.background,
        body: Center(child: CircularProgressIndicator(color: GameTheme.accent)),
      );
    }

    final avatarUrl = _profile?['avatar_url'] as String?;
    final username = _profile?['username'] ?? 'Player';
    final wins = _profile?['wins'] as int? ?? 0;
    final friendCode = _profile?['friend_code'] ?? 'Unknown';
    
    // Calculate rank
    PlayerRank rank;
    if (wins >= 50) rank = PlayerRank.platinum;
    else if (wins >= 25) rank = PlayerRank.gold;
    else if (wins >= 10) rank = PlayerRank.silver;
    else rank = PlayerRank.bronze;

    return Scaffold(
      backgroundColor: GameTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Profile', style: GameTheme.h2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: GameTheme.accent, width: 2),
                      boxShadow: [
                         BoxShadow(
                           color: GameTheme.accent.withValues(alpha: 0.3),
                           blurRadius: 20,
                           spreadRadius: 2,
                         )
                      ],
                      image: avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: GameTheme.surface,
                    ),
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 64, color: Colors.white54)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: GameTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Name with Edit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(username, style: GameTheme.h1),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: GameTheme.accent),
                  onPressed: () => _showEditUsernameDialog(username),
                  tooltip: 'Edit Username',
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Rank Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getRankColors(rank),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rank.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Stats Grid
            Row(
              children: [
                Expanded(child: _buildStatItem('WINS', wins.toString())),
                const SizedBox(width: 16),
                Expanded(child: _buildStatItem('RANK', rank.name.toUpperCase())),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Friend Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GameTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, color: GameTheme.accent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FRIEND CODE', style: GameTheme.label),
                        Text(friendCode, style: GameTheme.body),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: friendCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GameTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(value, style: GameTheme.h1.copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text(label, style: GameTheme.label),
        ],
      ),
    );
  }
  
  List<Color> _getRankColors(PlayerRank rank) {
    switch (rank) {
      case PlayerRank.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFFA05A2C)];
      case PlayerRank.silver:
        return [const Color(0xFFC0C0C0), const Color(0xFF808080)];
      case PlayerRank.gold:
        return [const Color(0xFFFFD700), const Color(0xFFDAA520)];
      case PlayerRank.platinum:
        return [const Color(0xFFE5E4E2), const Color(0xFFB0C4DE)];
    }
  }
}
