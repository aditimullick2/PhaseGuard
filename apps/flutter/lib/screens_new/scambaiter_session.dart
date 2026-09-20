import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/pg_animations.dart';
import '../widgets/pg_custom_icons.dart';
import '../state/session_controller.dart';
import '../services/local_scambaiter_service.dart';

const int maxRecordingDuration = 15; // 15 seconds

class ScambaiterSession extends StatefulWidget {
  const ScambaiterSession({super.key});

  @override
  State<ScambaiterSession> createState() => _ScambaiterSessionState();
}

class _ScambaiterSessionState extends State<ScambaiterSession> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LocalScambaiterService _scambaiterService = LocalScambaiterService();
  
  bool isScambaiterActive = true;
  bool isSendingPrompt = false;
  bool isRecording = false;
  int recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    // Auto-start listening and backend session when scambaiter screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      session.startLiveAudioIfNeeded();
      if (!session.wsConnected && !session.connecting) {
        session.startSession();
      }
      
      // Listen to scambaiter service events
      _scambaiterService.responseStream.listen((event) {
        if (event['event'] == 'recording_started') {
          setState(() {
            isRecording = true;
            recordingDuration = 0;
          });
        } else if (event['event'] == 'recording_stopped') {
          setState(() {
            isRecording = false;
            recordingDuration = event['duration'] ?? 0;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _scambaiterService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendPrompt(SessionController session, String text) async {
    if (text.trim().isEmpty || isSendingPrompt) return;
    setState(() => isSendingPrompt = true);
    _promptController.clear();
    await session.sendScambaiterPrompt(text);
    _scrollToBottom();
    setState(() => isSendingPrompt = false);
  }

  Future<void> _toggleRecording() async {
    if (isRecording) {
      await _scambaiterService.stopRecording();
    } else {
      await _scambaiterService.startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    // Use real session conversation — never fall back to hardcoded mock
    final conversationLog = session.scambaiterConversation;
    final pdiScore = session.pdiScore;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PgColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scambaiter Agent',
          style: TextStyle(
            color: PgColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Row(
            children: [
              Text(
                isScambaiterActive ? 'AI ACTIVE' : 'STANDBY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isScambaiterActive ? PgColors.safe : PgColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: isScambaiterActive,
                onChanged: (value) async {
                  setState(() {
                    isScambaiterActive = value;
                  });
                  if (value) {
                    await session.activateScambaiter();
                  }
                },
                activeThumbColor: PgColors.accent,
              ),
            ],
          ),
          const SizedBox(width: PgSpace.sm),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            _buildLiveMetricsBar(session, pdiScore),
            _buildScenarioChips(session),
            Expanded(
              child: conversationLog.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(PgSpace.lg),
                      itemCount: conversationLog.length,
                      itemBuilder: (context, index) {
                        final message = conversationLog[index];
                        return _buildMessageBubble(message);
                      },
                    ),
            ),
            _buildPromptInputBar(session),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 56,
              color: PgColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: PgSpace.lg),
          const Text(
            'AI Scambaiter Ready',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.sm),
          const Text(
            'Inject a scam scenario above or type\na caller line to start the AI counter-response.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: PgColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetricsBar(SessionController session, double pdiScore) {
    final scoreColor = pdiScore >= 0.70
        ? PgColors.scam
        : pdiScore >= 0.40
            ? PgColors.suspicious
            : PgColors.safe;
    final isStreaming = session.isStreamingAudio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PgSpace.lg, vertical: PgSpace.md),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: scoreColor.withValues(alpha: 0.35), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // Mini PDI gauge display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PDI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: scoreColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(pdiScore * 100).round()}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: scoreColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: PgSpace.md),
          // PDI bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pdiScore >= 0.70
                          ? '🚨 SCAM DETECTED'
                          : pdiScore >= 0.40
                              ? '⚠️ SUSPICIOUS'
                              : '✅ SAFE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isStreaming ? PgColors.accent : PgColors.textMuted,
                        shape: BoxShape.circle,
                        boxShadow: isStreaming
                            ? [BoxShadow(color: PgColors.accentGlow, blurRadius: 6)]
                            : [],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(PgRadii.bar),
                  child: LinearProgressIndicator(
                    value: pdiScore.clamp(0.0, 1.0),
                    backgroundColor: PgColors.bgElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                LiveWaveform(
                  height: 24,
                  barCount: 20,
                  isAnalyzing: isStreaming,
                  activeColor: scoreColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: PgSpace.md),
          // Synthetic score
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI VOICE',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: PgColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(session.syntheticVoiceScore * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: session.isSynthetic ? PgColors.scam : PgColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isCaller = message['role'] == 'caller';
    final text = message['text'] ?? '';
    final hasRedFlag = isCaller &&
        (text.toLowerCase().contains('badge number') ||
            text.toLowerCase().contains('back taxes') ||
            text.toLowerCase().contains('irs') ||
            text.toLowerCase().contains('5000') ||
            text.toLowerCase().contains('otp') ||
            text.toLowerCase().contains('gift card') ||
            text.toLowerCase().contains('trojan') ||
            text.toLowerCase().contains('customs') ||
            text.toLowerCase().contains('police') ||
            text.toLowerCase().contains('arrest'));

    return Padding(
      padding: const EdgeInsets.only(bottom: PgSpace.lg),
      child: Column(
        crossAxisAlignment: isCaller ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Red-flag LLM Threat Tag
          if (hasRedFlag)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PgColors.scam.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                  border: Border.all(color: PgColors.scam.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: PgColors.scam.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: PgColors.scam,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: PgColors.scam, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'RED-FLAG DETECTED: Impersonation & Coercion',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: PgColors.scam,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Avatar and Sender Tag Header
          Row(
            mainAxisAlignment: isCaller ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isCaller) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PgColors.scam.withValues(alpha: 0.18),
                    border: Border.all(color: PgColors.scam, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: PgColors.scam.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    size: 15,
                    color: PgColors.scam,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCaller
                      ? PgColors.scam.withValues(alpha: 0.12)
                      : PgColors.accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: isCaller
                        ? PgColors.scam.withValues(alpha: 0.4)
                        : PgColors.accent.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                ),
                child: Text(
                  isCaller ? 'Scammer (Caller)' : 'PhaseGuard AI Persona',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isCaller ? PgColors.scam : PgColors.accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (!isCaller) ...[
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: PgColors.accent.withValues(alpha: 0.18),
                    border: Border.all(color: PgColors.accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: PgColors.accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const PgCustomIcon(
                    type: PgIconType.cyberbot,
                    size: 16,
                    color: PgColors.accent,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                message['timestamp'] ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: PgColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: PgSpace.md, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCaller
                    ? [
                        const Color(0xFF1C1926),
                        PgColors.bgSecondary,
                      ]
                    : [
                        const Color(0xFF0E2233),
                        const Color(0xFF131D2E),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(PgRadii.card),
                topRight: const Radius.circular(PgRadii.card),
                bottomLeft: isCaller ? const Radius.circular(2) : const Radius.circular(PgRadii.card),
                bottomRight: isCaller ? const Radius.circular(PgRadii.card) : const Radius.circular(2),
              ),
              border: Border.all(
                color: isCaller
                    ? (hasRedFlag
                        ? PgColors.scam.withValues(alpha: 0.55)
                        : PgColors.scam.withValues(alpha: 0.3))
                    : PgColors.accent.withValues(alpha: 0.35),
                width: hasRedFlag ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCaller
                      ? (hasRedFlag
                          ? PgColors.scam.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.2))
                      : PgColors.accent.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildHighlightedText(text, isCaller),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, bool isCaller) {
    if (!isCaller) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: PgColors.textPrimary,
          height: 1.45,
        ),
      );
    }

    const redFlagPhrases = [
      'badge number 12345', 'badge number', 'back taxes', 'IRS', '5000',
      'OTP', 'gift card', 'arrest', 'trojan', 'customs', 'police',
    ];
    final lowerText = text.toLowerCase();

    String? matchedPhrase;
    for (final phrase in redFlagPhrases) {
      if (lowerText.contains(phrase.toLowerCase())) {
        matchedPhrase = phrase;
        break;
      }
    }

    if (matchedPhrase == null) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: PgColors.textPrimary,
          height: 1.45,
        ),
      );
    }

    final startIndex = lowerText.indexOf(matchedPhrase.toLowerCase());
    final before = text.substring(0, startIndex);
    final match = text.substring(startIndex, startIndex + matchedPhrase.length);
    final after = text.substring(startIndex + matchedPhrase.length);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: PgColors.textPrimary,
          height: 1.45,
        ),
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: PgColors.scam.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: PgColors.scam.withValues(alpha: 0.6)),
              ),
              child: Text(
                match,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7B7B),
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  Widget _buildScenarioChips(SessionController session) {
    final scenarios = [
      r'🚨 IRS Badge 12345: Pay $5,000 back taxes or face arrest.',
      r'🏦 Bank Alert: Unusual transaction of $1,420 detected. Send OTP to cancel.',
      '📦 Customs Notice: Illegal narcotics detected in international parcel.',
      '💻 Tech Support: Your Windows device has 3 Trojan viruses.',
      '⚡ Power Dept: Electricity disconnection scheduled in 30 minutes.',
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: PgSpace.xs),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: PgSpace.md),
        scrollDirection: Axis.horizontal,
        itemCount: scenarios.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = scenarios[index];
          return ActionChip(
            backgroundColor: PgColors.bgSecondary.withValues(alpha: 0.8),
            side: BorderSide(color: PgColors.scam.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PgRadii.pill),
            ),
            avatar: const Icon(Icons.bolt, size: 14, color: PgColors.scam),
            label: Text(
              s.split(':').first,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PgColors.textPrimary,
              ),
            ),
            onPressed: () => _handleSendPrompt(session, s),
          );
        },
      ),
    );
  }

  Widget _buildPromptInputBar(SessionController session) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: PgColors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recording indicator
            if (isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: PgColors.scam.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PgColors.scam.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: PgColors.scam,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🎙️ Recording: ${recordingDuration}s / 15s',
                      style: const TextStyle(
                        color: PgColors.scam,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Recording button
                IconButton(
                  onPressed: _toggleRecording,
                  icon: Icon(
                    isRecording ? Icons.stop : Icons.mic,
                    color: isRecording ? PgColors.scam : PgColors.accent,
                  ),
                  tooltip: isRecording ? 'Stop Recording' : 'Start Recording',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: PgColors.bgPrimary,
                      borderRadius: BorderRadius.circular(PgRadii.button),
                      border: Border.all(color: PgColors.border),
                    ),
                    child: TextField(
                      controller: _promptController,
                      style: const TextStyle(color: PgColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Simulate scam speech / inject prompt...',
                        hintStyle: TextStyle(color: PgColors.textMuted, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (text) => _handleSendPrompt(session, text),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [PgColors.accent, PgColors.accentGlow],
                    ),
                    borderRadius: BorderRadius.circular(PgRadii.button),
                    boxShadow: [
                      BoxShadow(
                    color: PgColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: isSendingPrompt
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () => _handleSendPrompt(session, _promptController.text),
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