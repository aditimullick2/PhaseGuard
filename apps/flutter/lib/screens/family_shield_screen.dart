import 'package:flutter/material.dart';

import '../components/app_theme.dart';
import '../services/family_shield_service.dart';
import 'family_voice_enrollment_screen.dart';
import 'family_contact_details_screen.dart';

/// Family Shield: manage up to 5 trusted family contacts + their voiceprints.
class FamilyShieldScreen extends StatefulWidget {
  const FamilyShieldScreen({super.key});

  @override
  State<FamilyShieldScreen> createState() => _FamilyShieldScreenState();
}

class _FamilyShieldScreenState extends State<FamilyShieldScreen> {
  final _service = FamilyShieldService();
  List<FamilyContact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await _service.listContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    if (_contacts.length >= 5) {
      _showSnack('Maximum 5 trusted contacts allowed.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddContactDialog(
        onAdd: (name, relationship) async {
          final contact = await _service.createContact(
            name: name,
            relationship: relationship,
          );
          if (mounted) {
            setState(() {
              final idx = _contacts.indexWhere((c) => c.id == contact.id);
              if (idx >= 0) {
                _contacts[idx] = contact;
              } else {
                _contacts.add(contact);
              }
            });
            _showSnack('${contact.name} added to Family Shield.');
          }
        },
      ),
    );
  }

  Future<void> _openEnrollment(FamilyContact contact) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => FamilyVoiceEnrollmentScreen(contact: contact),
      ),
    );
    if (result != null && mounted) {
      // Update local state to reflect voiceprint enrollment
      setState(() {
        final idx = _contacts.indexWhere((c) => c.id == contact.id);
        if (idx >= 0) {
          _contacts[idx] = contact.copyWith(
            hasVoiceprint: true,
            voiceStatus: 'enrolled',
            voiceProfileId: result['voice_profile_id'] as String?,
          );
        }
      });
      _showSnack('Voice enrolled for ${contact.name}!');
    }
  }

  Future<void> _renameContact(FamilyContact contact) async {
    final nameController = TextEditingController(text: contact.name);
    final relationshipController = TextEditingController(text: contact.relationship);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename ${contact.name}', style: AppTextStyles.titleSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Name',
                hintStyle: AppTextStyles.labelSmall,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationshipController,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Relationship',
                hintStyle: AppTextStyles.labelSmall,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Save',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      try {
        final name = nameController.text.trim();
        final relationship = relationshipController.text.trim();
        
        if (name.isEmpty) {
          _showSnack('Name cannot be empty');
          return;
        }
        
        final updated = await _service.updateContact(
          contactId: contact.id,
          name: name,
          relationship: relationship,
        );
        setState(() {
          final idx = _contacts.indexWhere((c) => c.id == contact.id);
          if (idx >= 0) {
            _contacts[idx] = updated.copyWith(updatedAt: DateTime.now());
          }
        });
        _showSnack('Contact updated successfully');
      } catch (e) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
    
    nameController.dispose();
    relationshipController.dispose();
  }

  Future<void> _openDetails(FamilyContact contact) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FamilyContactDetailsScreen(contact: contact),
      ),
    );
    if (result == true && mounted) {
      // Contact was deleted, reload the list
      _loadContacts();
    }
  }

  Future<void> _toggleEnabled(FamilyContact contact) async {
    try {
      final updated = await _service.updateContact(
        contactId: contact.id,
        isEnabled: !contact.isEnabled,
      );
      if (mounted) {
        setState(() {
          final idx = _contacts.indexWhere((c) => c.id == contact.id);
          if (idx >= 0) _contacts[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmDelete(FamilyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${contact.name}?', style: AppTextStyles.titleSmall),
        content: Text(
          'This will permanently delete their voiceprint. This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _service.deleteContact(contact.id);
        if (mounted) {
          setState(() => _contacts.removeWhere((c) => c.id == contact.id));
          _showSnack('${contact.name} removed from Family Shield.');
        }
      } catch (e) {
        if (mounted) {
          _showSnack(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.secondaryBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primaryText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Family Shield', style: AppTextStyles.titleSmall),
          ],
        ),
        actions: [
          if (!_loading && _contacts.length < 5)
            IconButton(
              icon: const Icon(Icons.person_add_rounded,
                  color: AppColors.primary, size: 22),
              tooltip: 'Add trusted contact',
              onPressed: _showAddContactDialog,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.secondaryBackground,
          onRefresh: _loadContacts,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _HeroCard(contactCount: _contacts.length),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: _ErrorState(
                      error: _error!, onRetry: _loadContacts),
                )
              else if (_contacts.isEmpty)
                SliverFillRemaining(
                  child: _EmptyState(onAdd: _showAddContactDialog),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverList.separated(
                    itemCount: _contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return _ContactCard(
                        contact: contact,
                        onEnroll: () => _openEnrollment(contact),
                        onToggle: () => _toggleEnabled(contact),
                        onDelete: () => _confirmDelete(contact),
                        onRename: () => _renameContact(contact),
                        onDetails: () => _openDetails(contact),
                      );
                    },
                  ),
                ),
                // Add contact slot if room
                if (_contacts.length < 5)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    sliver: SliverToBoxAdapter(
                      child: _AddContactSlot(onTap: _showAddContactDialog),
                    ),
                  )
                else
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 24),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final int contactCount;
  const _HeroCard({required this.contactCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Trusted Family Contacts',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$contactCount / 5',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Register family members and capture their unique voice prints. '
            'During calls, PhaseGuard can verify whether the voice matches a trusted member.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.onPrimaryContainer, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Chip(Icons.fingerprint, 'Voiceprint ID'),
              const SizedBox(width: 8),
              _Chip(Icons.phone_in_talk_rounded, 'Live Call Check'),
              const SizedBox(width: 8),
              _Chip(Icons.lock_rounded, 'Offline Safe'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondaryText, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(fontSize: 10, color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

// ── Contact card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final FamilyContact contact;
  final VoidCallback onEnroll;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onDetails;

  const _ContactCard({
    required this.contact,
    required this.onEnroll,
    required this.onToggle,
    required this.onDelete,
    required this.onRename,
    required this.onDetails,
  });

  Color get _avatarColorA => contact.isEnabled
      ? AppColors.primary
      : AppColors.secondaryText.withValues(alpha: 0.6);
  Color get _avatarColorB =>
      contact.isEnabled ? AppColors.secondary : AppColors.accent3;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetails,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: contact.isEnabled
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.alternate.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_avatarColorA, _avatarColorB],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        contact.name.isNotEmpty
                            ? contact.name[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.titleSmall,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.name,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: contact.isEnabled
                                  ? AppColors.primaryText
                                  : AppColors.secondaryText,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          contact.relationship.isNotEmpty
                              ? contact.relationship
                              : 'Trusted Contact',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  // Enable / disable toggle
                  Switch(
                    value: contact.isEnabled,
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primary20,
                    inactiveThumbColor: AppColors.secondaryText,
                    inactiveTrackColor: AppColors.surface30,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: AppColors.alternate.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 12),

              // Status row
              Row(
                children: [
                  // Voiceprint status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: contact.hasVoiceprint
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          contact.hasVoiceprint
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          color: contact.hasVoiceprint
                              ? AppColors.success
                              : AppColors.warning,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          contact.hasVoiceprint ? 'Voice enrolled' : 'No voice',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: contact.hasVoiceprint
                                ? AppColors.success
                                : AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Enroll / re-enroll button
                  OutlinedButton.icon(
                    onPressed: onEnroll,
                    icon: Icon(
                      contact.hasVoiceprint
                          ? Icons.refresh_rounded
                          : Icons.mic_external_on_rounded,
                      size: 14,
                    ),
                    label: Text(contact.hasVoiceprint ? 'Re-enroll' : 'Enroll'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rename
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.primary, size: 20),
                    onPressed: onRename,
                    tooltip: 'Rename contact',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 4),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Remove contact',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom_rounded,
                color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 24),
          Text('No trusted contacts yet',
              style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Add up to 5 family members and enroll their voice prints. '
            'PhaseGuard will alert you if a caller claims to be one of them.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.secondaryText, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add Family Member'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: AppTextStyles.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  bool get isNetworkError => 
      error.toLowerCase().contains('internet') ||
      error.toLowerCase().contains('network') ||
      error.toLowerCase().contains('connection') ||
      error.toLowerCase().contains('socket');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNetworkError ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            isNetworkError ? 'No internet connection' : 'Could not load contacts',
            style: AppTextStyles.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isNetworkError 
                ? 'Please check your network connection and try again'
                : error,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add contact slot ──────────────────────────────────────────────────────────

class _AddContactSlot extends StatelessWidget {
  final VoidCallback onTap;
  const _AddContactSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Add another family member',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Contact Dialog ────────────────────────────────────────────────────────

class _AddContactDialog extends StatefulWidget {
  final Future<void> Function(String name, String relationship) onAdd;
  const _AddContactDialog({required this.onAdd});

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Common relationship presets
  static const _presets = [
    'Mother', 'Father', 'Brother', 'Sister', 'Spouse',
    'Son', 'Daughter', 'Grandparent', 'Uncle', 'Aunt',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onAdd(
        name,
        _relationshipController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text('Add Trusted Contact', style: AppTextStyles.titleSmall),
              ],
            ),
            const SizedBox(height: 20),

            // Name field
            Text('Full Name *',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.secondaryText)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'e.g., Priya Sharma',
                hintStyle: AppTextStyles.labelSmall,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // Relationship field
            Text('Relationship',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.secondaryText)),
            const SizedBox(height: 6),
            TextField(
              controller: _relationshipController,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'e.g., Mother, Father, Spouse…',
                hintStyle: AppTextStyles.labelSmall,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 10),

            // Preset chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presets.map((p) {
                return GestureDetector(
                  onTap: () {
                    _relationshipController.text = p;
                    if (_nameController.text.trim().isEmpty) {
                      _nameController.text = p;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(p,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        )),
                  ),
                );
              }).toList(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.error)),
            ],

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      side: const BorderSide(color: AppColors.alternate),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Add Contact'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
