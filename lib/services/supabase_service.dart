// import 'dart:io'; // Removed for Web compatibility
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'dart:math'; // For Random.secure()
import 'dart:typed_data'; // For Uint8List

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;

  /// Initialize Supabase (call from main.dart)
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  /// Sign in anonymously (for quick start)
  Future<void> signInAnonymously() async {
    await _supabase.auth.signInAnonymously();
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return response;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  /// Check if a username is available (case-insensitive check recommended but exact for now)
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle(); // Returns null if not found
          
      return response == null;
    } catch (e) {
      print('Error checking username: $e');
      return false; // Fail safe
    }
  }

  /// Update profile fields
  Future<void> updateProfile({String? username, String? avatarUrl}) async {
    if (currentUser == null) return;
    
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    try {
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUser!.id);
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to update profile. Username might be taken.');
    }
  }

  /// Upload avatar image with compression
  Future<String?> uploadAvatar(XFile imageFile) async {
    if (currentUser == null) return null;

    try {
      // 1. Read bytes directly (works on Web & Mobile)
      Uint8List bytes = await imageFile.readAsBytes();

      // 2. Check size & compress if needed
      if (bytes.lengthInBytes > AppConfig.maxAvatarSizeBytes) {
         print('⚠️ Image size (${bytes.lengthInBytes} B) exceeds limit. Compressing...');
         try {
           final compressed = await FlutterImageCompress.compressWithList(
             bytes,
             minHeight: 512,
             minWidth: 512,
             quality: 70, // Aggressive compression
           );
           bytes = compressed;
         } catch(e) {
           print('Compression error: $e');
           // Fallback: try uploading original if compression fails, but it might be rejected by logic below
         }
      }
      
      // 3. Strict Limit Check
      if (bytes.lengthInBytes > AppConfig.maxAvatarSizeBytes) {
         throw Exception('Image too large (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB). Max allowed is 200KB.');
      }

      // 4. Upload to Storage
      final fileExt = path.extension(imageFile.path);
      // Ensure extension matches content (we always compress to jpg if we compress, but keeping original ext is fine for now if logic holds)
      // Actually, compressWithList output depends on format but defaults usually.
      // Let's safe-guard by using .jpg if we compressed, or keep original.
      final String finalExt = (bytes.lengthInBytes != (await imageFile.length())) ? '.jpg' : fileExt;

      final fileName = '${currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}$finalExt';
      
      await _supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );

      // 5. Get Public URL
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      rethrow; // Rethrow so UI can show error message
    }
  }

  // Removed unused _compressImage method as we now use compressWithList inside uploadAvatar
  
  /// Create a new lobby with 6-digit number code
  Future<String?> createLobby() async {
    if (currentUser == null) return null;
    
    // Generate 6 digit code safely
    final rng = Random.secure();
    for (int i = 0; i < 3; i++) {
        try {
          final code = (100000 + rng.nextInt(900000)).toString();
          
          final response = await _supabase
              .from('lobbies')
              .insert({
                'host_id': currentUser!.id,
                'status': 'waiting',
                'code': code, 
              })
              .select()
              .single();
              
          return response['id'] as String;
        } catch (e) {
          print('Error creating lobby (attempt $i): $e');
          if (i == 2) return null;
        }
    }
    return null;
  }

  /// Get lobby by code
  Future<Map<String, dynamic>?> getLobbyByCode(String code) async {
    try {
      final response = await _supabase
          .from('lobbies')
          .select()
          .eq('code', code)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update lobby status (e.g. 'playing')
  Future<void> updateLobbyStatus(String matchId, String status) async {
    if (currentUser == null) return;
    
    await _supabase
        .from('lobbies')
        .update({'status': status})
        .eq('id', matchId);
  }

  /// Stream lobby updates
  Stream<Map<String, dynamic>> streamLobby(String matchId) {
    return _supabase
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((event) => event.single);
  }
  // --- Invitations ---

  /// Send an invite to a player by username
  Future<void> sendInvite(String receiverUsername, String matchId) async {
    if (currentUser == null) throw Exception('Not signed in');
    
    // 1. Find user by username
    final receiver = await _supabase
        .from('profiles')
        .select('id')
        .eq('username', receiverUsername)
        .maybeSingle();
        
    if (receiver == null) {
      throw Exception('User not found');
    }
    
    final receiverId = receiver['id'] as String;
    if (receiverId == currentUser!.id) {
       throw Exception('Cannot invite yourself');
    }
    
    // 2. Insert invite (check if one exists pending?)
    // For simplicity, just insert.
    await _supabase.from('invitations').insert({
      'sender_id': currentUser!.id,
      'receiver_id': receiverId,
      'match_id': matchId,
      'status': 'pending',
    });
  }
  
  /// Stream of pending invitations for the current user
  Stream<List<Map<String, dynamic>>> getInvitesStream() {
    if (currentUser == null) return const Stream.empty();
    
    return _supabase
        .from('invitations')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUser!.id)
        .order('created_at', ascending: false)
        .map((maps) => maps.where((m) => m['status'] == 'pending').toList());
  }
  
  /// Respond to an invite
  Future<void> respondToInvite(String inviteId, bool accept) async {
    await _supabase
        .from('invitations')
        .update({
          'status': accept ? 'accepted' : 'rejected'
        })
        .eq('id', inviteId);
  }

  
  /// Increment win count for current user
  Future<void> incrementWin() async {
    if (currentUser == null) return;
    
    try {
      // 1. Get current wins
      final profile = await getProfile();
      final currentWins = (profile?['wins'] as int?) ?? 0;
      
      // 2. Update wins + 1
      await _supabase
          .from('profiles')
          .update({'wins': currentWins + 1})
          .eq('id', currentUser!.id);
          
      print('🏆 Win recorded! Total: ${currentWins + 1}');
    } catch (e) {
      print('Error incrementing wins: $e');
    }
  }
}
