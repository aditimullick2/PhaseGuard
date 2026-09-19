import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';

class SimpleCallInterface extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onAnswer;
  final VoidCallback onReject;

  const SimpleCallInterface({
    super.key,
    required this.phoneNumber,
    required this.onAnswer,
    required this.onReject,
  });

  @override
  State<SimpleCallInterface> createState() => _SimpleCallInterfaceState();
}

class _SimpleCallInterfaceState extends State<SimpleCallInterface> {
  bool isProtectionActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(PgSpace.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: PgColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Incoming Call',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PgColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    PgColors.accent,
                    PgColors.accentDim,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: PgColors.accentGlow,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 60,
                color: PgColors.bgPrimary,
              ),
            ),
            const SizedBox(height: PgSpace.xl),
            Text(
              widget.phoneNumber,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: PgColors.textPrimary,
              ),
            ),
            const SizedBox(height: PgSpace.sm),
            const Text(
              'Incoming call...',
              style: TextStyle(
                fontSize: 16,
                color: PgColors.textSecondary,
              ),
            ),
            const SizedBox(height: PgSpace.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isProtectionActive 
                    ? PgColors.safe.withValues(alpha: 0.15)
                    : PgColors.bgSecondary,
                border: Border.all(
                  color: isProtectionActive ? PgColors.safe : PgColors.border,
                ),
                borderRadius: BorderRadius.circular(PgRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProtectionActive ? Icons.shield : Icons.shield_outlined,
                    color: isProtectionActive ? PgColors.safe : PgColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isProtectionActive ? 'Protection Active' : 'Protection Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isProtectionActive ? PgColors.safe : PgColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(PgSpace.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: widget.onReject,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PgColors.scam,
                        boxShadow: [
                          BoxShadow(
                            color: PgColors.scam.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: PgColors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onAnswer,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PgColors.safe,
                        boxShadow: [
                          BoxShadow(
                            color: PgColors.safe.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        color: PgColors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(PgSpace.lg),
              child: SwitchListTile(
                title: const Text(
                  'Enable Protection',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PgColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Activate scam detection during call',
                  style: TextStyle(
                    fontSize: 12,
                    color: PgColors.textSecondary,
                  ),
                ),
                value: isProtectionActive,
                onChanged: (value) {
                  setState(() {
                    isProtectionActive = value;
                  });
                },
                activeThumbColor: PgColors.accent,
              ),
            ),
            const SizedBox(height: PgSpace.lg),
          ],
        ),
      ),
    ),
  );
}
}