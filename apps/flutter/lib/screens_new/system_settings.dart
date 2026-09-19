import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../state/session_controller.dart';
import '../services/api_client.dart';

class SystemSettings extends StatefulWidget {
  const SystemSettings({super.key});

  @override
  State<SystemSettings> createState() => _SystemSettingsState();
}

class _SystemSettingsState extends State<SystemSettings> {
  String backendUrl = 'https://phaseguard.onrender.com';
  bool dspVoiceDetection = true;
  bool scambaiterEnabled = true;
  bool officialVerifiedAlerts = true;
  bool isTestingHealth = false;
  String? healthResult;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: PgColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'System Settings',
          style: TextStyle(
            color: PgColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PgSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectionStatus(session),
              const SizedBox(height: PgSpace.lg),
              _buildBackendConfig(session),
              const SizedBox(height: PgSpace.lg),
              _buildFeatureToggles(session),
              const SizedBox(height: PgSpace.lg),
              _buildModeStatus(session),
              const SizedBox(height: PgSpace.lg),
              _buildAboutSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(SessionController session) {
    final isLive = session.wsConnected;
    final isConnecting = session.connecting;
    final statusColor = isLive ? PgColors.safe : (isConnecting ? PgColors.suspicious : PgColors.accent);
    final statusText = isLive ? 'Connected (Live WSS)' : (isConnecting ? 'Connecting...' : 'Standby / Ready');

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connection Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PgSpace.sm),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              if (!isLive && !isConnecting)
                ElevatedButton(
                  onPressed: () => session.startSession(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PgColors.accent.withValues(alpha: 0.2),
                    foregroundColor: PgColors.accent,
                    side: const BorderSide(color: PgColors.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                Text(
                  session.callId != null
                      ? 'Call: ${session.callId!.substring(0, session.callId!.length > 8 ? 8 : session.callId!.length)}...'
                      : 'WSS Protocol',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PgColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackendConfig(SessionController session) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Backend Host & Health',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PgColors.textSecondary,
                ),
              ),
              if (isTestingHealth)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PgColors.accent),
                ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          TextField(
            controller: TextEditingController(text: backendUrl),
            decoration: InputDecoration(
              labelText: 'Production API & WSS URL',
              labelStyle: const TextStyle(color: PgColors.textSecondary),
              hintText: 'https://phaseguard.onrender.com',
              hintStyle: const TextStyle(color: PgColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PgRadii.bar),
                borderSide: const BorderSide(color: PgColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PgRadii.bar),
                borderSide: const BorderSide(color: PgColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PgRadii.bar),
                borderSide: const BorderSide(color: PgColors.accent),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.health_and_safety_outlined, color: PgColors.safe),
                tooltip: 'Test Health',
                onPressed: () async {
                  setState(() {
                    isTestingHealth = true;
                    healthResult = null;
                  });
                  final ok = await ApiClient(baseUrl: backendUrl).healthCheck();
                  setState(() {
                    isTestingHealth = false;
                    healthResult = ok ? 'Backend Online (200 OK)' : 'Health check failed (Timeout / Offline)';
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(healthResult!),
                        backgroundColor: ok ? PgColors.safe : PgColors.scam,
                      ),
                    );
                  }
                },
              ),
            ),
            style: const TextStyle(color: PgColors.textPrimary),
          ),
          if (healthResult != null) ...[
            const SizedBox(height: PgSpace.xs),
            Text(
              healthResult!,
              style: TextStyle(
                fontSize: 11,
                color: healthResult!.contains('Online') ? PgColors.safe : PgColors.scam,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureToggles(SessionController session) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Feature Toggles',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          _buildToggleItem(
            'AI Voice Detector (DSP)',
            'Real-time acoustic analysis',
            session.dspEnabled,
            (value) {
              session.enableDsp(value);
            },
          ),
          const SizedBox(height: PgSpace.md),
          _buildToggleItem(
            'Scambaiter Agent',
            'AI persona defense engagement',
            scambaiterEnabled,
            (value) {
              setState(() {
                scambaiterEnabled = value;
              });
            },
          ),
          const SizedBox(height: PgSpace.md),
          _buildToggleItem(
            'National Cybercell Alerts',
            'Automated fraud escalation',
            officialVerifiedAlerts,
            (value) {
              setState(() {
                officialVerifiedAlerts = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PgColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: PgColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: PgColors.accent,
        ),
      ],
    );
  }

  Widget _buildModeStatus(SessionController session) {
    final mode = session.operationalMode;
    final isFull = mode == 'full';
    final modeColor = isFull ? PgColors.safe : PgColors.suspicious;

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational Mode',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  border: Border.all(color: modeColor),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                ),
                child: Text(
                  mode.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: modeColor,
                  ),
                ),
              ),
              const SizedBox(width: PgSpace.sm),
              Expanded(
                child: Text(
                  isFull
                      ? 'All services operational'
                      : 'Limited mode - some features unavailable',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PgColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About PhaseGuard',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          _buildAboutRow('Version', '2.0.0 (Flutter)'),
          const SizedBox(height: PgSpace.sm),
          _buildAboutRow('Engine', 'PhaseGuard DSP Triad-v2'),
          const SizedBox(height: PgSpace.sm),
          _buildAboutRow('Backend', 'https://phaseguard.onrender.com'),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: PgColors.textMuted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PgColors.textSecondary,
          ),
        ),
      ],
    );
  }
}