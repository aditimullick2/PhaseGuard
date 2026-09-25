import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_directory_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_background.dart';
import '../../models/app_user.dart';
import '../../services/call_signaling_service.dart';
import '../../services/in_app_calling_service.dart';
import 'name_selection_screen.dart';
import 'outgoing_call_screen.dart';

class ProtectedCallHubScreen extends StatefulWidget {
  const ProtectedCallHubScreen({super.key});

  @override
  State<ProtectedCallHubScreen> createState() => _ProtectedCallHubScreenState();
}

class _ProtectedCallHubScreenState extends State<ProtectedCallHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserDirectoryService _directoryService = UserDirectoryService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final auth = context.read<AuthService>();
    setState(() {
      _currentUserId = auth.appUser?.uid;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startCall(AppUser callee, String type) async {
    final auth = context.read<AuthService>();
    final caller = auth.appUser;
    if (caller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait until your profile is loaded.'),
          backgroundColor: PgColors.suspicious,
        ),
      );
      return;
    }

    if (caller.uid == callee.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot call yourself.'),
          backgroundColor: PgColors.suspicious,
        ),
      );
      return;
    }

    try {
      final signaling = context.read<CallSignalingService>();
      final calling = context.read<InAppCallingService>();

      final call = await signaling.initiateCall(
        caller: caller,
        callee: callee,
        type: type,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OutgoingCallScreen(
              call: call,
              remoteUser: callee,
              signalingService: signaling,
              callingService: calling,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: PgColors.scam,
          ),
        );
      }
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController();
    final auth = Provider.of<AuthService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: PgColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PgColors.accent, foregroundColor: PgColors.bgPrimary),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                auth.updateDisplayName(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.signOut();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.appUser;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Column(
          children: [
            // Header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Protected Calls',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: PgColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (user != null)
                          IconButton(
                            icon: const Icon(Icons.edit, color: PgColors.textSecondary),
                            onPressed: _showRenameDialog,
                          ),
                      ],
                    ),
                    // Profile row
                    if (user != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PgColors.bgSecondary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(PgRadii.card),
                          border: Border.all(color: PgColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    PgColors.accent.withValues(alpha: 0.3),
                                    PgColors.accent.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: PgColors.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: PgColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: PgColors.safe,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NameSelectionScreen()),
                                );
                              },
                              child: const Text(
                                'Change name',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PgColors.accent,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _signOut,
                              child: const Text(
                                'Sign out',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PgColors.scam,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: PgColors.accent,
              unselectedLabelColor: PgColors.textSecondary,
              indicatorColor: PgColors.accent,
              tabs: const [
                Tab(text: 'Contacts'),
                Tab(text: 'Recent'),
              ],
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContactsTab(),
                  _buildRecentTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsTab() {
    if (_currentUserId == null) {
      return const Center(
        child: Text(
          'Loading user profile...',
          style: TextStyle(color: PgColors.textSecondary),
        ),
      );
    }

    return StreamBuilder<List<AppUser>>(
      stream: _directoryService.streamUsers(currentUserId: _currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: PgColors.scam),
                const SizedBox(height: 16),
                Text(
                  'Error loading contacts',
                  style: TextStyle(fontSize: 16, color: PgColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 12, color: PgColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: PgColors.accent),
          );
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 48, color: PgColors.textSecondary),
                const SizedBox(height: 16),
                const Text(
                  'No contacts available',
                  style: TextStyle(fontSize: 16, color: PgColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'When other users set up their profiles, they will appear here.',
                  style: TextStyle(fontSize: 12, color: PgColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final onlineThreshold = now.subtract(const Duration(minutes: 2));

        return ListView.builder(
          padding: const EdgeInsets.all(PgSpace.md),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isOnline = user.lastSeen.isAfter(onlineThreshold);

            return Container(
              margin: const EdgeInsets.only(bottom: PgSpace.sm),
              padding: const EdgeInsets.all(PgSpace.md),
              decoration: BoxDecoration(
                color: PgColors.bgSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(PgRadii.card),
                border: Border.all(color: PgColors.border),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isOnline
                            ? [PgColors.safe.withValues(alpha: 0.3), PgColors.safe.withValues(alpha: 0.1)]
                            : [PgColors.textMuted.withValues(alpha: 0.3), PgColors.textMuted.withValues(alpha: 0.1)],
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      color: isOnline ? PgColors.safe : PgColors.textMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: PgColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? PgColors.safe : PgColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                color: isOnline ? PgColors.safe : PgColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Call buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: PgColors.accent, size: 20),
                        tooltip: 'Start Audio Call',
                        onPressed: () => _startCall(user, 'audio'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam, color: PgColors.accent, size: 20),
                        tooltip: 'Start Video Call',
                        onPressed: () => _startCall(user, 'video'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentTab() {
    return const Center(
      child: Text(
        'Recent calls will be loaded from Firebase',
        style: TextStyle(color: PgColors.textSecondary),
      ),
    );
  }
}
