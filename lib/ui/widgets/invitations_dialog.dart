import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../theme/game_theme.dart';
import '../../state/game_provider.dart';
import '../screens/game_screen.dart';

class InvitationsDialog extends ConsumerWidget {
  const InvitationsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stream of invites
    final invitesStream = SupabaseService().getInvitesStream();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 450,
        height: 500,
        decoration: GameTheme.glassDecoration,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Invitations 💌', style: GameTheme.h2),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: GameTheme.textSecondary),
                ),
              ],
            ),
            const Divider(color: GameTheme.glassBorder, height: 32),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: invitesStream,
                builder: (context, snapshot) {
                   if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: GameTheme.error)));
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   
                   final invites = snapshot.data!;
                   if (invites.isEmpty) {
                     return Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.mail_outline, size: 48, color: GameTheme.textSecondary.withValues(alpha: 0.5)),
                           const SizedBox(height: 16),
                           const Text('No pending invitations', style: TextStyle(color: GameTheme.textSecondary, fontStyle: FontStyle.italic)),
                         ],
                       ),
                     );
                   }
                   
                   return ListView.builder(
                     itemCount: invites.length,
                     itemBuilder: (ctx, i) {
                       final invite = invites[i];
                       return _InviteTile(invite: invite);
                     },
                   );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> invite;
  const _InviteTile({required this.invite});

  @override
  ConsumerState<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends ConsumerState<_InviteTile> {
  bool _isLoading = false;

  Future<void> _respond(bool accept) async {
    setState(() => _isLoading = true);
    try {
      final inviteId = widget.invite['id'];
      final matchId = widget.invite['match_id'];
      
      await SupabaseService().respondToInvite(inviteId, accept);
      
      if (accept && mounted) {
        Navigator.pop(context); // Close dialog
        // Join game logic
        ref.read(gameStateProvider.notifier).joinGame(matchId);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen()));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We ideally want sender name, but that requires a join. 
    // For MVP, we can fetch profile or just show "Invited to match X"
    return Card(
       color: const Color(0xFFF1F5F9), // Solid Slate 100
       elevation: 0,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
         side: const BorderSide(color: GameTheme.glassBorder),
       ),
       margin: const EdgeInsets.symmetric(vertical: 8),
       child: ListTile(
         leading: const Icon(Icons.mail, color: GameTheme.primary),
         title: const Text('Game Invitation'),
         subtitle: Text('Match Code: ${widget.invite['match_id']}'),
         trailing: _isLoading 
           ? const CircularProgressIndicator()
           : Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 IconButton(
                   icon: const Icon(Icons.check_circle, color: Colors.green),
                   onPressed: () => _respond(true),
                   tooltip: 'Accept',
                 ),
                 IconButton(
                   icon: const Icon(Icons.cancel, color: Colors.red),
                   onPressed: () => _respond(false),
                   tooltip: 'Decline',
                 ),
               ],
             ),
       ),
    );
  }
}
