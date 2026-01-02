/// Main Navigation Screen with Bottom Tab Bar
/// 
/// This is the primary navigation hub with 5 tabs:
/// 1. Missions - Daily challenges for coins
/// 2. Shop - Card backs, avatars, music
/// 3. Battle - Home screen with game modes (default)
/// 4. Friends - Friend list and match creation
/// 5. Profile - User stats and settings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'missions_tab.dart';
import 'shop_screen.dart';
import 'battle_tab.dart';
import 'friends_tab.dart';
import 'profile_screen.dart';
import '../../services/supabase_service.dart'; // Fixed import
import '../theme/game_theme.dart';
import '../widgets/currency_display.dart';
import 'gem_shop_screen.dart';

/// Provider to track current tab index
final currentTabProvider = StateProvider<int>((ref) => 2); // Default to Battle tab

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> 
    with TickerProviderStateMixin {
  
  late final List<Widget> _screens;
  late AnimationController _glassAnimationController;
  late Animation<double> _glassAnimation;
  Map<String, dynamic>? _profile; // Added state
  
  @override
  void initState() {
    super.initState();
    _loadProfile(); // Fetch profile
    
    _screens = [
      const MissionsTab(),
      const ShopScreen(),
      const BattleTab(),
      const FriendsTab(),
      const ProfileScreen(),
    ];
    
    // Liquid glass animation controller
    _glassAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _glassAnimation = CurvedAnimation(
      parent: _glassAnimationController,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService().getProfile();
    if (mounted) {
      setState(() => _profile = profile);
    }
  }
  
  @override
  void dispose() {
    _glassAnimationController.dispose();
    super.dispose();
  }
  
  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    
    // Trigger liquid glass animation
    _glassAnimationController.forward(from: 0);
    
    ref.read(currentTabProvider.notifier).state = index;
  }
  
  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabProvider);
    
    return Scaffold(
      backgroundColor: Colors.white, // Explicit white to prevent black screen
      resizeToAvoidBottomInset: false, // Prevent layout jumps
      body: Material(
        color: Colors.white, // Double insurance for opacity
        child: SafeArea(
          child: Column(
          children: [
            // Currency Header (tappable)
            _buildCurrencyHeader(),
            
            // Main Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(currentIndex),
                  child: _screens[currentIndex],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(currentIndex),
    );
  }
  
  Widget _buildCurrencyHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12), // Adjusted padding (right 16)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Currency (Tappable)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GemShopScreen()),
              );
            },
            child: const CurrencyDisplay(compact: false, large: true),
          ),
          
          const SizedBox(width: 12), // Spacing
          
          // Profile Icon (Tappable) - Leads to Profile Tab (Index 4)
          GestureDetector(
            onTap: () => _onTabTapped(4),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: GameTheme.softShadow,
                color: Colors.grey.shade200,
              ),
              child: ClipOval(
                child: _profile?['avatar_url'] != null
                    ? Image.network(
                        _profile!['avatar_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_,__,___) => const Icon(Icons.person, color: Colors.grey),
                      )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomNavBar(int currentIndex) {
    return AnimatedBuilder(
      animation: _glassAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.check_circle_outline, 'Missions', currentIndex),
                  _buildNavItem(1, Icons.shopping_bag_outlined, 'Shop', currentIndex),
                  _buildNavItem(2, Icons.sports_esports, 'Battle', currentIndex, isCenter: true),
                  _buildNavItem(3, Icons.waving_hand_outlined, 'Friends', currentIndex),
                  _buildNavItem(4, Icons.person_outline, 'Profile', currentIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildNavItem(int index, IconData icon, String label, int currentIndex, {bool isCenter = false}) {
    final isSelected = index == currentIndex;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isCenter ? 20 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isCenter ? GameTheme.primary : GameTheme.primary.withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isCenter ? 20 : 16),
          // Liquid glass effect on selection
          boxShadow: isSelected && isCenter ? [
            BoxShadow(
              color: GameTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected 
                    ? (isCenter ? Colors.white : GameTheme.primary)
                    : GameTheme.textSecondary,
                size: isCenter ? 28 : 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected 
                    ? (isCenter ? Colors.white : GameTheme.primary)
                    : GameTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
