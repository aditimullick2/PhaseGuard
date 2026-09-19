import 'package:flutter/material.dart';

import '../services/incall_service.dart';
import '../theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';
import 'stt_test_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: PgColors.screenGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: PgSpace.screenH),
            child: _SettingsContent(),
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  bool callMonitoring = true;
  bool autoBlock = false;
  bool realTimeAlerts = true;
  bool deepfakeDetection = true;
  bool voiceAuth = true;
  bool factChecking = true;

  // ── Default Dialer state ─────────────────────────────────────────────────
  final _inCallService = InCallService();
  bool? _isDefaultDialer; // null = checking, true/false = result
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultDialer();
  }

  @override
  void dispose() {
    _inCallService.dispose();
    super.dispose();
  }

  Future<void> _checkDefaultDialer() async {
    final result = await _inCallService.isDefaultDialer();
    if (mounted) setState(() => _isDefaultDialer = result);
  }

  Future<void> _requestDefaultDialer() async {
    setState(() => _isRequesting = true);
    await _inCallService.requestDefaultDialer();
    // Re-check after user interacts with the system dialog
    await _checkDefaultDialer();
    if (mounted) setState(() => _isRequesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionTitle('Settings'),
        const SizedBox(height: PgSpace.section),
        _buildSettingsGroup(
          title: 'Protection',
          items: [
            _SettingItem(
              label: 'Call Monitoring',
              value: callMonitoring,
              onChanged: (value) {
                setState(() => callMonitoring = value);
              },
            ),
            _SettingItem(
              label: 'Auto Block',
              value: autoBlock,
              onChanged: (value) {
                setState(() => autoBlock = value);
              },
            ),
            _SettingItem(
              label: 'Real-time Alerts',
              value: realTimeAlerts,
              onChanged: (value) {
                setState(() => realTimeAlerts = value);
              },
            ),
          ],
        ),
        const SizedBox(height: PgSpace.section),
        _buildSettingsGroup(
          title: 'Detection',
          items: [
            _SettingItem(
              label: 'Deepfake Detection',
              value: deepfakeDetection,
              onChanged: (value) {
                setState(() => deepfakeDetection = value);
              },
            ),
            _SettingItem(
              label: 'Voice Authentication',
              value: voiceAuth,
              onChanged: (value) {
                setState(() => voiceAuth = value);
              },
            ),
            _SettingItem(
              label: 'Fact Checking',
              value: factChecking,
              onChanged: (value) {
                setState(() => factChecking = value);
              },
            ),
          ],
        ),
        const SizedBox(height: PgSpace.section),
        // ── Call Permissions ─────────────────────────────────────────────────
        _buildSectionLabel('Call Permissions'),
        const SizedBox(height: 12),
        _buildDefaultDialerCard(),
        const SizedBox(height: PgSpace.section),
        _buildSettingsGroup(
          title: 'About',
          items: [
            _SettingItem(
              label: 'App Version',
              value: null,
              subtitle: '1.0.0',
              onChanged: null,
            ),
            _SettingItem(
              label: 'API Endpoint',
              value: null,
              subtitle: 'phaseguard.onrender.com',
              onChanged: null,
            ),
          ],
        ),
        const SizedBox(height: PgSpace.section),
        // ── Developer Tools ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: const Text(
            'Developer Tools',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PgColors.mediumBlue,
            ),
          ),
        ),
        GlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PgColors.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PgColors.accentBlue.withOpacity(0.3)),
              ),
              child: const Icon(Icons.mic_rounded, color: PgColors.lightBlue, size: 20),
            ),
            title: const Text(
              'Test Local STT',
              style: TextStyle(color: PgColors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: const Text(
              'On-device Speech-to-Text (speech_to_text)',
              style: TextStyle(color: PgColors.mediumBlue, fontSize: 11),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: PgColors.mediumBlue),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SttTestScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: PgColors.mediumBlue,
        ),
      ),
    );
  }

  Widget _buildDefaultDialerCard() {
    final isDefault = _isDefaultDialer;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PgColors.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PgColors.accentBlue.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: PgColors.lightBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Default Phone App',
                        style: TextStyle(color: PgColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('Required for InCallService & call control',
                        style: TextStyle(color: PgColors.mediumBlue, fontSize: 11)),
                  ],
                ),
              ),
              _buildStatusBadge(isDefault),
            ],
          ),
          if (isDefault != true) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRequesting ? null : _requestDefaultDialer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PgColors.accentBlue,
                  foregroundColor: PgColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isRequesting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: PgColors.white))
                    : const Icon(Icons.verified_user_rounded, size: 16),
                label: Text(
                  _isRequesting ? 'Opening\u2026' : 'Make PhaseGuard Default Dialer',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (isDefault == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C896).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00C896).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF00C896), size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PhaseGuard can now answer and reject calls programmatically.',
                      style: TextStyle(color: Color(0xFF00C896), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool? isDefault) {
    if (isDefault == null) {
      return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: PgColors.mediumBlue));
    }
    if (isDefault) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00C896).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00C896).withValues(alpha: 0.4)),
        ),
        child: const Text('Active',
            style: TextStyle(color: Color(0xFF00C896), fontSize: 10, fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: const Text('Not Set',
          style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<_SettingItem> items,
  }) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PgColors.mediumBlue,
            ),
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: _buildSettingItem(entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildSettingItem(_SettingItem item) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PgColors.white,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (item.value != null) ...[
            const SizedBox(width: 12),
            Switch(
              value: item.value ?? false,
              onChanged: item.onChanged,
              activeThumbImage: null,
              inactiveThumbColor: PgColors.mediumBlue,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingItem {
  final String label;
  final bool? value;
  final String? subtitle;
  final Function(bool)? onChanged;

  _SettingItem({
    required this.label,
    required this.value,
    this.subtitle,
    required this.onChanged,
  });
}
