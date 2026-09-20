import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_translations.dart';
import '../models/user.dart';
import '../models/call.dart';

import '../services/permission_service.dart';
import '../components/app_theme.dart';
import '../components/bottom_nav.dart';
import '../components/avatar_status.dart';
import '../components/contact_tile.dart';
import '../components/animated_gif_background.dart';
import '../components/animated_gradient_bg.dart';
import '../components/app_button.dart';
import '../components/security_overlay_modal.dart';


import 'call_screen.dart';
import 'incoming_call_screen.dart';
import 'call_history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  String? _lastShownCallId;
  bool _isShowingIncomingCall = false;
  Timer? _incomingCallTimer;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.primaryBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Profile not found.\nPlease sign out and register again.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    content: 'Sign Out',
                    onTap: () {
                      ref.read(authServiceProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          );
        }

        // Incoming call listener with debouncing
        ref.listen<AsyncValue<CallModel?>>(
          incomingCallsProvider(user.uid),
          (previous, next) {
            final call = next.value;
            if (call == null) {
              _isShowingIncomingCall = false;
              _incomingCallTimer?.cancel();
              return;
            }
            
            // Prevent duplicate incoming call screens
            if (_isShowingIncomingCall) {
              debugPrint('[HomeScreen] Incoming call already showing, skipping duplicate');
              return;
            }
            
            // Debounce: wait 500ms before showing to prevent rapid duplicates
            _incomingCallTimer?.cancel();
            _incomingCallTimer = Timer(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              
              // Check again if still showing to prevent race conditions
              if (_isShowingIncomingCall) {
                debugPrint('[HomeScreen] Incoming call already showing after debounce, skipping');
                return;
              }
              
              if (_lastShownCallId == call.callId) return;
              _lastShownCallId = call.callId;
              _isShowingIncomingCall = true;

              debugPrint('[HomeScreen] Showing incoming call screen for call: ${call.callId}');
              
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => IncomingCallScreen(call: call),
                  transitionsBuilder: (_, animation, __, child) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              ).then((_) {
                // Reset flag when incoming call screen is dismissed
                _isShowingIncomingCall = false;
                debugPrint('[HomeScreen] Incoming call screen dismissed');
              });
            });
          },
        );

        // Determine background gif per tab
        final String? bgGif = switch (_selectedIndex) {
          0 => 'assets/background/home_bg.gif',
          1 => 'assets/background/contacts_bg.gif',
          2 => 'assets/background/history_bg.gif',
          _ => null, // Profile has its own background internally
        };

        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: _selectedIndex != 3 ? _buildAppBar(user) : null,
          body: Stack(
            children: [
              // Animated background (tabs 0–2)
              if (bgGif != null)
                Positioned.fill(
                  child: AnimatedGifBackground(
                    key: ValueKey(_selectedIndex),
                    assetPath: bgGif,
                    overlayOpacity: _selectedIndex == 2 ? 0.78 : 0.6,
                    child: const SizedBox.shrink(),
                  ),
                ),

              // Tab content
              SafeArea(
                top: _selectedIndex != 3,
                bottom: false,
                child: switch (_selectedIndex) {
                  0 => _HomeTab(
                      currentUser: user,
                      onGoToContacts: () => setState(() => _selectedIndex = 1),
                      onGoToHistory: () => setState(() => _selectedIndex = 2),
                      onStartCall: (callee, type) =>
                          _startCallFromHome(callee, type, user),
                    ),
                  1 => _ContactsTab(currentUser: user),
                  2 => const CallHistoryScreen(),
                  _ => ProfileScreen(user: user),
                },
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 24),
                AppButton(
                  content: 'Sign Out & Reset',
                  onTap: () {
                    ref.read(authServiceProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startCallFromHome(
      UserModel callee, String type, UserModel caller) async {
    final status = await ref
        .read(permissionServiceProvider)
        .requestCallPermissions(requireCamera: type == 'video');
    if (status != CallPermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera & Microphone permissions required.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    try {
      final call = await ref.read(callingServiceProvider).startCall(
            caller: caller,
            callee: callee,
            type: type,
          );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: call.callId,
              remoteUser: callee,
              isCaller: true,
              callType: type,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar(UserModel user) {
    final locale = ref.watch(localeProvider);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        switch (_selectedIndex) {
          0 => AppTranslations.get(locale, 'home'),
          1 => AppTranslations.get(locale, 'contacts'),
          2 => AppTranslations.get(locale, 'history'),
          _ => AppTranslations.get(locale, 'settings'),
        },
        style: AppTextStyles.titleLarge,
      ),
      actions: [
        // Profile avatar — taps to Settings tab
        Semantics(
          label: 'Open profile settings',
          button: true,
          child: GestureDetector(
            onTap: () => setState(() => _selectedIndex = 3),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AvatarStatus(
                name: user.name,
                size: 36,
                online: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _incomingCallTimer?.cancel();
    super.dispose();
  }
}


//  Home Tab (index 0) 

class _HomeTab extends ConsumerWidget {
  final UserModel currentUser;
  final VoidCallback onGoToContacts;
  final VoidCallback onGoToHistory;
  final Future<void> Function(UserModel callee, String type) onStartCall;

  const _HomeTab({
    required this.currentUser,
    required this.onGoToContacts,
    required this.onGoToHistory,
    required this.onStartCall,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider(currentUser.uid));
    final locale = ref.watch(localeProvider);

    return CustomScrollView(
      slivers: [
        //  Greeting Header 
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(locale),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser.name.isNotEmpty
                      ? currentUser.name.split(' ').first
                      : 'Friend',
                  style: AppTextStyles.titleLarge.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        //  Quick Action Cards 
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    icon: Icons.people_rounded,
                    label: AppTranslations.get(locale, 'contacts'),
                    sublabel: AppTranslations.get(locale, 'contacts_sub'),
                    color: AppColors.primary,
                    onTap: onGoToContacts,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.history_rounded,
                    label: AppTranslations.get(locale, 'history'),
                    sublabel: AppTranslations.get(locale, 'history_sub'),
                    color: AppColors.secondary,
                    onTap: onGoToHistory,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),

        // Online Now 
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppTranslations.get(locale, 'online_now'), style: AppTextStyles.titleMedium),
                GestureDetector(
                  onTap: onGoToContacts,
                  child: Text(
                    AppTranslations.get(locale, 'see_all'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: usersAsync.when(
            data: (users) {
              final online = users
                  .where((u) =>
                      u.uid != currentUser.uid && u.isOnline)
                  .take(8)
                  .toList();

              if (online.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: GlassmorphicContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.secondaryText, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            AppTranslations.get(locale, 'offline'),
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  height: 90,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: online.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 24),
                    itemBuilder: (context, index) {
                      final u = online[index];
                      return RecentItem(
                        name: u.name,
                        photoUrl: u.photoUrl,
                        online: true,
                        onTap: () => onStartCall(u, 'audio'),
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),

        // Security Status Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const PhaseGuardHomeCard(),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        //  Call Stats Card 
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _StatsCard(currentUser: currentUser),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)), // nav padding
      ],
    );
  }

  String _greeting(String locale) {
    final h = DateTime.now().hour;
    if (h < 12) return AppTranslations.get(locale, 'good_morning');
    if (h < 17) return AppTranslations.get(locale, 'good_afternoon');
    return AppTranslations.get(locale, 'good_evening');
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassmorphicContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(label, style: AppTextStyles.titleSmall),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  final UserModel currentUser;

  const _StatsCard({required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callsAsync = ref.watch(callHistoryProvider(currentUser.uid));

    final locale = ref.watch(localeProvider);

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: callsAsync.when(
        data: (calls) {
          final total = calls.length;
          final missed = calls.where((c) =>
              c.calleeId == currentUser.uid && c.status == 'missed').length;
          final totalDuration =
              calls.fold<int>(0, (sum, c) => sum + (c.duration ?? 0));
          final minutes = totalDuration ~/ 60;

          return Row(
            children: [
              _StatItem(label: AppTranslations.get(locale, 'total_calls'), value: '$total'),
              _StatDivider(),
              _StatItem(label: AppTranslations.get(locale, 'missed'), value: '$missed'),
              _StatDivider(),
              _StatItem(label: AppTranslations.get(locale, 'minutes'), value: '$minutes'),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 60,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        error: (_, __) => Text('Stats unavailable',
            style: AppTextStyles.bodySmall),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.alternate);
  }
}


//  Contacts Tab (index 1)


class _ContactsTab extends ConsumerStatefulWidget {
  final UserModel currentUser;

  const _ContactsTab({required this.currentUser});

  @override
  ConsumerState<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends ConsumerState<_ContactsTab> {
  String _searchQuery = '';

  Future<void> _startCall(
      UserModel callee, String type, BuildContext context) async {
    final status = await ref.read(permissionServiceProvider).requestCallPermissions(requireCamera: type == 'video');
    final hasPerms = status == CallPermissionStatus.granted;
    if (!hasPerms) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera & Microphone permissions required.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      final call = await ref.read(callingServiceProvider).startCall(
            caller: widget.currentUser,
            callee: callee,
            type: type,
          );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: call.callId,
              remoteUser: callee,
              isCaller: true,
              callType: type,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider(widget.currentUser.uid));
    final locale = ref.watch(localeProvider);

    return usersAsync.when(
      data: (users) {
        final filteredUsers = users.where((u) {
          if (u.uid == widget.currentUser.uid) return false;
          if (_searchQuery.isEmpty) return true;
          return u.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Sort: Online first
        filteredUsers.sort((a, b) {
          if (a.isOnline && !b.isOnline) return -1;
          if (!a.isOnline && b.isOnline) return 1;
          return a.name.compareTo(b.name);
        });

        // Recents (first 5 online for demo)
        final recents = filteredUsers.where((u) => u.isOnline).take(5).toList();

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: AppSearchBar(
                  hint: AppTranslations.get(locale, 'search_by_name'),
                  value: _searchQuery,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onClear: () => setState(() => _searchQuery = ''),
                ),
              ),
            ),
            
            if (_searchQuery.isEmpty && recents.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Text(AppTranslations.get(locale, 'recents'), style: AppTextStyles.titleMedium),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 90,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: recents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 24),
                      itemBuilder: (context, index) {
                        final u = recents[index];
                        return RecentItem(
                          name: u.name,
                          photoUrl: u.photoUrl,
                          online: u.isOnline,
                          onTap: () => _startCall(u, 'audio', context),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Text(AppTranslations.get(locale, 'all_contacts'), style: AppTextStyles.titleMedium),
              ),
            ),
            
            if (filteredUsers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 60, color: AppColors.alternate),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty 
                            ? AppTranslations.get(locale, 'no_contacts_yet') 
                            : '${AppTranslations.get(locale, 'no_matches_for')} "$_searchQuery".',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final u = filteredUsers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ContactTile(
                          name: u.name,
                          photoUrl: u.photoUrl,
                          isOnline: u.isOnline,
                          status: u.isOnline 
                              ? AppTranslations.get(locale, 'active_now') 
                              : AppTranslations.get(locale, 'offline'),
                          onAudioCall: () => _startCall(u, 'audio', context),
                          onVideoCall: () => _startCall(u, 'video', context),
                        ),
                      );
                    },
                    childCount: filteredUsers.length,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ShimmerItem(),
      ),
      error: (err, stack) => Center(
        child: Text('Error loading contacts: $err',
            style: const TextStyle(color: AppColors.error)),
      ),
    );
  }
}
