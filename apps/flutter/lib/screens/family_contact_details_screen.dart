import 'package:flutter/material.dart';

import '../components/app_theme.dart';
import '../services/family_shield_service.dart';
import 'family_voice_enrollment_screen.dart';

/// Family Shield Contact Details Screen
/// Allows viewing and managing individual trusted contact details
class FamilyContactDetailsScreen extends StatefulWidget {
  final FamilyContact contact;

  const FamilyContactDetailsScreen({super.key, required this.contact});

  @override
  State<FamilyContactDetailsScreen> createState() => _FamilyContactDetailsScreenState();
}

class _FamilyContactDetailsScreenState extends State<FamilyContactDetailsScreen> {
  final _service = FamilyShieldService();
  late FamilyContact _contact;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

  Future<void> _reloadContact() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final contacts = await _service.listContacts();
      final updated = contacts.firstWhere((c) => c.id == _contact.id);
      if (mounted) {
        setState(() {
          _contact = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _toggleEnabled() async {
    try {
      final updated = await _service.updateContact(
        contactId: _contact.id,
        isEnabled: !_contact.isEnabled,
      );
      if (mounted) {
        setState(() => _contact = updated);
        _showSnack('${_contact.name} ${updated.isEnabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${_contact.name}?', style: AppTextStyles.titleSmall),
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
        await _service.deleteContact(_contact.id);
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate deletion
          _showSnack('${_contact.name} removed from Family Shield.');
        }
      } catch (e) {
        if (mounted) {
          _showSnack(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _openEnrollment() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => FamilyVoiceEnrollmentScreen(contact: _contact),
      ),
    );
    if (result != null && mounted) {
      await _reloadContact();
      _showSnack('Voice enrolled for ${_contact.name}!');
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
        title: Text('Contact Details', style: AppTextStyles.titleSmall),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar and basic info
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _contact.isEnabled
                              ? [AppColors.primary, AppColors.secondary]
                              : [
                                  AppColors.secondaryText.withValues(alpha: 0.6),
                                  AppColors.accent3
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _contact.name.isNotEmpty
                              ? _contact.name[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.titleLarge.copyWith(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _contact.name,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contact.relationship.isNotEmpty
                          ? _contact.relationship
                          : 'Trusted Contact',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Status card
              _buildStatusCard(),

              const SizedBox(height: 24),

              // Voice ID status
              _buildVoiceIdCard(),

              const SizedBox(height: 24),

              // Actions
              _buildActions(),

              const SizedBox(height: 32),

              // Danger zone
              _buildDangerZone(),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _contact.isEnabled
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.alternate.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _contact.isEnabled ? Icons.check_circle_rounded : Icons.block_rounded,
            color: _contact.isEnabled ? AppColors.success : AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _contact.isEnabled ? 'Enabled' : 'Disabled',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _contact.isEnabled ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _contact.isEnabled
                      ? 'This contact will be used for voice verification'
                      : 'This contact is not used for verification',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _contact.isEnabled,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary20,
            inactiveThumbColor: AppColors.secondaryText,
            inactiveTrackColor: AppColors.surface30,
            onChanged: (_) => _toggleEnabled(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceIdCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.alternate.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _contact.hasVoiceprint
                    ? Icons.fingerprint_rounded
                    : Icons.fingerprint,
                color: _contact.hasVoiceprint ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice ID',
                style: AppTextStyles.labelMedium,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _contact.hasVoiceprint
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _contact.hasVoiceprint ? 'Active' : 'Not Enrolled',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _contact.hasVoiceprint
                        ? AppColors.success
                        : AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _contact.hasVoiceprint
                ? 'Voice sample enrolled and ready for verification'
                : 'No voice sample enrolled. Record a voice sample to enable verification.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          if (_contact.hasVoiceprint) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Status: ',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                Text(
                  _contact.voiceStatus.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _openEnrollment,
          icon: Icon(
            _contact.hasVoiceprint
                ? Icons.refresh_rounded
                : Icons.mic_external_on_rounded,
            size: 18,
          ),
          label: Text(_contact.hasVoiceprint ? 'Re-enroll Voice' : 'Enroll Voice'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: AppTextStyles.labelMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danger Zone',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remove Contact',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete ${_contact.name} and their voice print from Family Shield.',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deleteContact,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Remove Contact'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
