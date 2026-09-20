import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_translations.dart';
import '../models/call.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';

import '../components/app_theme.dart';
import '../components/call_history_tile.dart';
import '../components/app_button.dart';
import '../services/permission_service.dart';
import 'call_screen.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  int _tabIndex = 0; // 0: All, 1: Missed

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final locale = ref.watch(localeProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: TabGroup(
                labels: [
                  AppTranslations.get(locale, 'all_calls'),
                  AppTranslations.get(locale, 'missed'),
                ],
                selectedIndex: _tabIndex,
                onChanged: (idx) => setState(() => _tabIndex = idx),
              ),
            ),
            Expanded(
              child: _HistoryList(currentUser: user, showOnlyMissed: _tabIndex == 1),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.error)),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final UserModel currentUser;
  final bool showOnlyMissed;
  
  const _HistoryList({required this.currentUser, this.showOnlyMissed = false});

  String _formatTime(DateTime time, String locale) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '${AppTranslations.get(locale, 'today')}, ${DateFormat.jm().format(time)}';
    } else if (time.year == now.year && time.month == now.month && time.day == now.day - 1) {
      return '${AppTranslations.get(locale, 'yesterday')}, ${DateFormat.jm().format(time)}';
    }
    return DateFormat('MMM d, h:mm a').format(time);
  }

  Future<void> _callBack(WidgetRef ref, BuildContext context, CallModel call, String type) async {
    final permissionStatus = await ref.read(permissionServiceProvider).requestCallPermissions(requireCamera: type == 'video');
    final hasPerms = permissionStatus == CallPermissionStatus.granted;
    if (!hasPerms) {
      if (context.mounted) {
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
      final isIncoming = call.calleeId == currentUser.uid;
      
      final calleeId = isIncoming ? call.callerId : call.calleeId;
      final calleeName = isIncoming ? call.callerName : call.calleeName;

      final callee = UserModel(
        uid: calleeId,
        email: '',
        name: calleeName,
        isOnline: false,
        fcmToken: null,
      );

      final newCall = await ref.read(callingServiceProvider).startCall(
            caller: currentUser,
            callee: callee,
            type: type,
          );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: newCall.callId,
              remoteUser: callee,
              isCaller: true,
              callType: type,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, String callId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Delete Call?',
                  style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Text(
                'This call record will be permanently removed from your history.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.secondaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      content: 'Cancel',
                      variant: 'outline',
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      content: 'Delete',
                      variant: 'destructive',
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('calls').doc(callId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Call record deleted'),
              backgroundColor: AppColors.secondaryBackground,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callsAsync = ref.watch(callHistoryProvider(currentUser.uid));
    final locale = ref.watch(localeProvider);

    return callsAsync.when(
      data: (calls) {
        var filteredCalls = calls;
        if (showOnlyMissed) {
          filteredCalls = calls.where((c) {
            final isIncoming = c.calleeId == currentUser.uid;
            return isIncoming && c.status == 'missed';
          }).toList();
        }

        if (filteredCalls.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 60, color: AppColors.alternate),
                const SizedBox(height: 16),
                Text(
                  showOnlyMissed 
                      ? AppTranslations.get(locale, 'no_missed_calls') 
                      : AppTranslations.get(locale, 'no_call_history'),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  showOnlyMissed
                      ? AppTranslations.get(locale, 'all_calls_answered')
                      : AppTranslations.get(locale, 'start_call_contacts'),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: filteredCalls.length,
          itemBuilder: (context, index) {
            final call = filteredCalls[index];
            final isIncoming = call.calleeId == currentUser.uid;
            final otherName = isIncoming ? call.callerName : call.calleeName;
            
            bool isMissed = false;
            String typeStr = isIncoming ? 'incoming' : 'outgoing';
            
            if (call.status == 'missed' || call.status == 'rejected') {
              if (isIncoming) {
                isMissed = true;
                typeStr = 'missed';
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CallHistoryTile(
                name: otherName,
                time: _formatTime(call.startTime, locale),
                isMissed: isMissed,
                isVideo: call.type == 'video',
                type: typeStr,
                durationSeconds: call.duration,
                onCallBack: () => _callBack(ref, context, call, call.type),
                onDelete: () => _confirmDelete(context, call.callId),
              ),
            );
          },
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _HistoryShimmer(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Error loading history',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text('$e',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Simple shimmer skeleton for history loading state
class _HistoryShimmer extends StatefulWidget {
  const _HistoryShimmer();

  @override
  State<_HistoryShimmer> createState() => _HistoryShimmerState();
}

class _HistoryShimmerState extends State<_HistoryShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = AppColors.alternate.withValues(alpha: _anim.value);
        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.alternate),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 100, height: 14,
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 140, height: 10,
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
