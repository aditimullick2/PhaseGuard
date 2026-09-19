import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';
import '../theme/tokens.dart';

class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key});

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_isVisible) return;
    setState(() {
      _isVisible = true;
    });
    _animationController.forward();
  }

  void _hideOverlay() {
    if (!_isVisible) return;
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionController>(
      builder: (context, session, _) {
        if (session.overlayVisible && !_isVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
        }
        if (!session.overlayVisible && _isVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _hideOverlay());
        }

        if (!_isVisible && !session.overlayVisible) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildOverlayContent(session),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverlayContent(SessionController session) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: PgColors.bgPrimary.withValues(alpha: 0.85),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(session),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: PgSpace.screenH),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildCallerInfo(session),
                      const SizedBox(height: 32),
                      _buildOptionCards(session),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildFooter(session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SessionController session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PgSpace.screenH, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildPulsingDot(),
              const SizedBox(width: 8),
              Text(
                '• ANALYZING LIVE CALL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PgColors.lightBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: session.hideOverlay,
            icon: const Icon(Icons.close),
            color: PgColors.mediumBlue,
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: PgColors.safe,
        shape: BoxShape.circle,
      ),
      child: const _PulsingAnimation(),
    );
  }

  Widget _buildCallerInfo(SessionController session) {
    // Get caller info from session metadata
    final callerNumber = session.callerNumber ?? 'Unknown caller';
    final location = session.callerLocation ?? 'Location unknown';
    final showWarning = session.isPotentialScam;

    debugPrint('📱 Overlay showing caller: $callerNumber, location: $location');

    return Column(
      children: [
        Text(
          callerNumber,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: PgColors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (showWarning)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: PgColors.warn,
              ),
              const SizedBox(width: 4),
              Text(
                'Potential spoofing detected • $location',
                style: TextStyle(
                  fontSize: 13,
                  color: PgColors.warn,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        else
          Text(
            'Incoming call • $location',
            style: TextStyle(
              fontSize: 13,
              color: PgColors.mediumBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildOptionCards(SessionController session) {
    return Column(
      children: [
        _buildOptionCard(
          icon: Icons.verified_user,
          title: 'Live Verify Checker',
          description: 'Real-time fact checking against global scam databases',
          isRecommended: true,
          isEnabled: true,
          onTap: session.hideOverlay,
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          icon: Icons.smart_toy,
          title: 'Scambaiter AI',
          description: 'Deploy autonomous agent to frustrate and delay caller',
          isRecommended: false,
          isEnabled: session.callState == 'ACTIVE', // Only enabled when call is ACTIVE
          disabledReason: 'Available once the call is active',
          onTap: () async {
            if (session.callState == 'ACTIVE') {
              try {
                await session.activateScambaiter();
                session.callState = 'SCAMBAITER_ACTIVE';
                session.hideOverlay();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to activate scambaiter: $e'),
                      backgroundColor: PgColors.crit,
                    ),
                  );
                }
              }
            }
          },
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          icon: Icons.graphic_eq,
          title: 'AI Voice Detector',
          description: 'Experimental: Analyzing vocal tremors and synthetic patterns',
          isRecommended: false,
          isEnabled: session.dspEnabled,
          disabledReason: 'Experimental — currently off',
          onTap: () {
            if (session.dspEnabled) {
              session.hideOverlay();
            }
          },
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          icon: Icons.visibility,
          title: 'Continue Monitoring',
          description: 'Minimize to background and stay protected silently',
          isRecommended: false,
          isEnabled: true,
          onTap: () {
            session.hideOverlay();
            session.continueMonitoring().catchError((_) {});
          },
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isRecommended,
    required bool isEnabled,
    String? disabledReason,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isEnabled
              ? PgColors.glassBgStrong
              : PgColors.glassBg.withValues(alpha: 0.03),
          border: Border.all(
            color: isEnabled
                ? PgColors.glassBorder
                : PgColors.glassBorder.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(PgRadii.glass),
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? PgColors.accentBlue.withValues(alpha: 0.2)
                        : PgColors.mediumBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PgRadii.icon),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? PgColors.accentBlue : PgColors.mediumBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? PgColors.white
                                  : PgColors.mediumBlue,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: PgColors.safe.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: PgColors.safe,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isEnabled
                              ? PgColors.mediumBlue
                              : PgColors.mediumBlue.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                      if (!isEnabled && disabledReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          disabledReason,
                          style: TextStyle(
                            fontSize: 10,
                            color: PgColors.warn,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isEnabled
                      ? PgColors.lightBlue
                      : PgColors.mediumBlue.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(SessionController session) {
    return Padding(
      padding: const EdgeInsets.all(PgSpace.screenH),
      child: GestureDetector(
        onTap: () async {
          // Terminate session
          await session.disconnect();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: PgColors.primaryBtn,
            ),
            borderRadius: BorderRadius.circular(PgRadii.bar),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.call_end,
                color: PgColors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'TERMINATE SESSION',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PgColors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingAnimation extends StatefulWidget {
  const _PulsingAnimation();

  @override
  State<_PulsingAnimation> createState() => _PulsingAnimationState();
}

class _PulsingAnimationState extends State<_PulsingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: PgColors.safe,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PgColors.safe.withValues(alpha: _animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
