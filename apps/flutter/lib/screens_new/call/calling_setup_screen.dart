import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_background.dart';

class CallingSetupScreen extends StatefulWidget {
  const CallingSetupScreen({super.key});

  @override
  State<CallingSetupScreen> createState() => _CallingSetupScreenState();
}

class _CallingSetupScreenState extends State<CallingSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _setupProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a display name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthService>();
      final result = await auth.signInAnonymously(preferredName: name);
      
      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Profile setup failed. Please try again.';
        });
        return;
      }
      
      if (mounted) {
        Navigator.of(context).pop(); // Return to previous screen
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'No network connection. Please check your internet and try again.';
    }
    
    if (errorStr.contains('anonymous') || errorStr.contains('auth')) {
      return 'Anonymous authentication is disabled in Firebase Console. Please enable it under Authentication > Sign-in method.';
    }
    
    if (errorStr.contains('firebase') || errorStr.contains('google-services')) {
      return 'Firebase not configured. Please ensure google-services.json is in android/app/ directory.';
    }
    
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied. Check Firebase security rules and your configuration.';
    }
    
    if (errorStr.contains('timestamp') || errorStr.contains('type cast')) {
      return 'Data format error. Profile will be created with default settings.';
    }
    
    return 'Setup failed: ${error.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PgSpace.lg, vertical: PgSpace.xl),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: PgColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Setup Protected Calling',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: PgColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        PgColors.accent.withValues(alpha: 0.3),
                        PgColors.accent.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: PgColors.accent, width: 2),
                  ),
                  child: const Icon(
                    Icons.phone_enabled,
                    size: 60,
                    color: PgColors.accent,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Create Your Protected Calling Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: PgColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Description
                Text(
                  'Set up your display name for secure peer-to-peer calling with live AI scam detection.',
                  style: TextStyle(
                    fontSize: 14,
                    color: PgColors.textSecondary.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Name input
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your display name',
                    filled: true,
                    fillColor: PgColors.bgSecondary.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PgRadii.card),
                      borderSide: BorderSide(color: PgColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PgRadii.card),
                      borderSide: BorderSide(color: PgColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PgRadii.card),
                      borderSide: BorderSide(color: PgColors.accent, width: 2),
                    ),
                    errorText: _errorMessage,
                  ),
                  style: const TextStyle(color: PgColors.textPrimary),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 30,
                ),
                
                const SizedBox(height: 24),
                
                // Setup button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _setupProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PgColors.accent,
                      foregroundColor: PgColors.bgPrimary,
                      disabledBackgroundColor: PgColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PgRadii.card),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(PgColors.bgPrimary),
                            ),
                          )
                        : const Text(
                            'Setup Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PgColors.safe.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PgRadii.card),
                    border: Border.all(color: PgColors.safe.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: PgColors.safe, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your profile is stored securely with Firebase. You can change your name anytime.',
                          style: TextStyle(
                            fontSize: 12,
                            color: PgColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
