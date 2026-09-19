import 'package:flutter/material.dart';

import '../services/accessibility_capture.dart';
import '../services/bluetooth_sco_capture.dart';
import '../services/call_socket.dart';
import '../services/shizuku_capture.dart';
import '../services/priority_recording.dart';
import '../services/realtime_scam_detection.dart';
import '../theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';
import 'scam_detection_demo.dart';
import 'local_scam_detection.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
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
            child: _CallsListView(),
          ),
        ),
      ),
    );
  }
}

class _CallsListView extends StatefulWidget {
  const _CallsListView();

  @override
  State<_CallsListView> createState() => _CallsListViewState();
}

class _CallsListViewState extends State<_CallsListView> {
  late List<CallRecord> calls;
  final CallSocket _callSocket = CallSocket();
  final AccessibilityCapture _accessibilityCapture = AccessibilityCapture();
  final BluetoothScoCapture _bluetoothScoCapture = BluetoothScoCapture();
  final ShizukuCapture _shizukuCapture = ShizukuCapture();
  final PriorityRecording _priorityRecording = PriorityRecording();
  bool _screenAudioEnabled = false;
  bool _screenAudioAvailable = false;
  bool _accessibilityEnabled = false;
  bool _bluetoothScoEnabled = false;
  bool _bluetoothHeadsetConnected = false;
  bool _shizukuEnabled = false;
  bool _priorityRecordingEnabled = false;
  String _deviceInfo = 'Checking...';
  String _accessibilityStatus = 'Checking...';
  String _bluetoothStatus = 'Checking...';
  String _shizukuStatus = 'Checking...';
  String _priorityRecordingStatus = 'Checking...';
  RecordingMethod _currentRecordingMethod = RecordingMethod.none;

  @override
  void initState() {
    super.initState();
    calls = [
      CallRecord(
        id: '1',
        caller: 'Unknown Number +91-XXXX123456',
        time: '2 hours ago',
        duration: '2:34',
        riskLevel: 'high',
        status: 'blocked',
      ),
      CallRecord(
        id: '2',
        caller: 'Bank Customer Service',
        time: '5 hours ago',
        duration: '5:12',
        riskLevel: 'low',
        status: 'safe',
      ),
      CallRecord(
        id: '3',
        caller: 'Government Portal',
        time: '1 day ago',
        duration: '3:45',
        riskLevel: 'high',
        status: 'monitored',
      ),
    ];
    
    _checkScreenAudioAvailability();
    _checkAccessibilityService();
    _checkBluetoothSco();
    _checkShizuku();
    _checkPriorityRecording();
    _accessibilityCapture.startListening();
    _bluetoothScoCapture.startListening();
    _shizukuCapture.startListening();
    _priorityRecording.resultStream.listen((result) {
      setState(() {
        _currentRecordingMethod = result.method;
        _priorityRecordingStatus = _priorityRecording.getMethodDisplayName(result.method);
      });
    });
  }
  
  @override
  void dispose() {
    _accessibilityCapture.dispose();
    _bluetoothScoCapture.dispose();
    _shizukuCapture.dispose();
    _priorityRecording.dispose();
    super.dispose();
  }
  
  Future<void> _checkScreenAudioAvailability() async {
    try {
      final available = await _callSocket.getScreenAudioDeviceInfo();
      setState(() {
        _screenAudioAvailable = available['available'] == true;
        _deviceInfo = _screenAudioAvailable 
            ? '${available['manufacturer']} ${available['model']} (Android ${available['android_version']})'
            : 'Not available on this device';
      });
    } catch (e) {
      setState(() {
        _screenAudioAvailable = false;
        _deviceInfo = 'Error: $e';
      });
    }
  }
  
  Future<void> _checkAccessibilityService() async {
    try {
      final enabled = await _accessibilityCapture.isServiceEnabled();
      await _accessibilityCapture.getServiceState();
      setState(() {
        _accessibilityEnabled = enabled;
        _accessibilityStatus = enabled 
            ? 'Active (Call: ${_accessibilityCapture.callStateLabel})'
            : 'Not enabled';
      });
    } catch (e) {
      setState(() {
        _accessibilityEnabled = false;
        _accessibilityStatus = 'Error: $e';
      });
    }
  }
  
  Future<void> _checkBluetoothSco() async {
    try {
      final info = await _bluetoothScoCapture.getDeviceInfo();
      setState(() {
        _bluetoothHeadsetConnected = info['headsetConnected'] == true;
        _bluetoothStatus = _bluetoothHeadsetConnected 
            ? 'Connected: ${info['deviceName'] ?? 'Unknown'}'
            : 'No headset connected';
      });
    } catch (e) {
      setState(() {
        _bluetoothHeadsetConnected = false;
        _bluetoothStatus = 'Error: $e';
      });
    }
  }
  
  Future<void> _checkShizuku() async {
    try {
      await _shizukuCapture.getShizukuState();
      setState(() {
        _shizukuStatus = _getShizukuStatusText(_shizukuCapture.currentState);
      });
    } catch (e) {
      setState(() {
        _shizukuStatus = 'Error: $e';
      });
    }
  }
  
  Future<void> _checkPriorityRecording() async {
    try {
      final status = await _priorityRecording.getRecordingStatus();
      setState(() {
        _priorityRecordingStatus = _priorityRecording.getMethodDisplayName(
          RecordingMethod.values.firstWhere(
            (e) => e.name == status['currentMethod'],
            orElse: () => RecordingMethod.none,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _priorityRecordingStatus = 'Error: $e';
      });
    }
  }
  
  String _getShizukuStatusText(ShizukuState state) {
    switch (state) {
      case ShizukuState.notInstalled:
        return 'Shizuku not installed';
      case ShizukuState.notRunning:
        return 'Shizuku not running';
      case ShizukuState.permissionNeeded:
        return 'Permission required';
      case ShizukuState.granted:
        return 'Ready (Experimental)';
      case ShizukuState.active:
        return 'Capture active';
      case ShizukuState.captureFailing:
        return 'Capture failing (silent)';
    }
  }
  
  Future<void> _toggleScreenAudio() async {
    if (_screenAudioEnabled) {
      await _callSocket.stopScreenAudioCapture();
      setState(() {
        _screenAudioEnabled = false;
      });
    } else {
      final success = await _callSocket.enableScreenAudioCapture(sampleRate: 16000);
      setState(() {
        _screenAudioEnabled = success;
      });
    }
  }
  
  Future<void> _enableAccessibilityService() async {
    final success = await _accessibilityCapture.enableService();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable PhaseGuard in Accessibility Settings'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _toggleBluetoothSco() async {
    if (_bluetoothScoEnabled) {
      await _bluetoothScoCapture.stopCapture();
      setState(() {
        _bluetoothScoEnabled = false;
      });
    } else {
      final success = await _bluetoothScoCapture.startCapture(sampleRate: 16000);
      setState(() {
        _bluetoothScoEnabled = success;
      });
    }
  }
  
  Future<void> _toggleShizuku() async {
    if (_shizukuEnabled) {
      // Stop capture
      final result = await _shizukuCapture.stopElevatedCapture();
      setState(() {
        _shizukuEnabled = false;
        _shizukuStatus = _getShizukuStatusText(_shizukuCapture.currentState);
      });
      
      // Show result message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Capture stopped'),
            backgroundColor: _shizukuCapture.nonZeroPercentage < 1.0 
                ? PgColors.crit 
                : PgColors.safe,
          ),
        );
      }
    } else {
      // Request permission first if needed
      if (_shizukuCapture.currentState == ShizukuState.permissionNeeded) {
        final result = await _shizukuCapture.requestPermission();
        setState(() {
          _shizukuStatus = _getShizukuStatusText(_shizukuCapture.currentState);
        });
        
        if (result['granted'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Permission denied'),
                backgroundColor: PgColors.crit,
              ),
            );
          }
          return;
        }
      }
      
      // Start Cally-like elevated capture (no MediaProjection needed)
      final result = await _shizukuCapture.startElevatedCapture(sampleRate: 16000);
      
      if (result['success'] == true) {
        setState(() {
          _shizukuEnabled = true;
          _shizukuStatus = _getShizukuStatusText(_shizukuCapture.currentState);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Capture started'),
              backgroundColor: PgColors.safe,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Capture failed'),
              backgroundColor: PgColors.crit,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _togglePriorityRecording() async {
    if (_priorityRecordingEnabled) {
      // Stop priority recording
      final result = await _priorityRecording.stopRecording();
      setState(() {
        _priorityRecordingEnabled = false;
        _priorityRecordingStatus = 'Idle';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? PgColors.safe : PgColors.crit,
          ),
        );
      }
    } else {
      // Start priority recording (automatic method selection)
      final result = await _priorityRecording.startRecording(sampleRate: 16000);
      
      if (result.success) {
        setState(() {
          _priorityRecordingEnabled = true;
          _priorityRecordingStatus = _priorityRecording.getMethodDisplayName(result.method);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_priorityRecording.getMethodDisplayName(result.method)}: ${result.message}'),
              backgroundColor: PgColors.safe,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: PgColors.crit,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionTitle('Call History'),
        const SizedBox(height: PgSpace.section),
        
        // Screen Audio Control
        if (_screenAudioAvailable) _buildScreenAudioControl(),
        if (!_screenAudioAvailable) _buildAudioNotAvailable(),
        
        const SizedBox(height: PgSpace.section),
        
        // Accessibility Service Control
        _buildAccessibilityServiceControl(),
        
        const SizedBox(height: PgSpace.section),
        
        // Bluetooth SCO Control
        _buildBluetoothScoControl(),
        
        const SizedBox(height: PgSpace.section),
        
        // Shizuku Control (Experimental)
        _buildShizukuControl(),
        
        const SizedBox(height: PgSpace.section),
        
        // Priority Recording Control (New - Recommended)
        _buildPriorityRecordingControl(),
        
        const SizedBox(height: PgSpace.section),
        
        // Scam Detection Demo (Backend AI Integration)
        _buildScamDetectionDemo(),
        
        const SizedBox(height: PgSpace.section),
        ...calls.map((call) => _buildCallItem(call)),
        const SizedBox(height: 100),
      ],
    );
  }
  
  Widget _buildScreenAudioControl() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screen Audio Capture',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PgColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _deviceInfo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _screenAudioEnabled,
                onChanged: (value) => _toggleScreenAudio(),
                activeTrackColor: PgColors.accentBlue,
                activeThumbColor: PgColors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _screenAudioEnabled 
                ? 'Capturing system audio (including calls)'
                : 'Enable to capture call audio for scam detection',
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.lightBlue,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAudioNotAvailable() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: PgColors.warn,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Screen audio capture not available on this device',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PgColors.lightBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Fallback: Enable speakerphone during calls for audio capture',
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.mediumBlue,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAccessibilityServiceControl() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessibility Service',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PgColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _accessibilityStatus,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                  ),
                ],
              ),
              if (!_accessibilityEnabled)
                ElevatedButton(
                  onPressed: _enableAccessibilityService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PgColors.accentBlue,
                    foregroundColor: PgColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Enable',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _accessibilityEnabled 
                ? 'Call detection and audio capture active'
                : 'Enable to detect calls and attempt audio capture',
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.lightBlue,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBluetoothScoControl() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bluetooth SCO',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PgColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bluetoothStatus,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                  ),
                ],
              ),
              if (_bluetoothHeadsetConnected)
                Switch(
                  value: _bluetoothScoEnabled,
                  onChanged: (value) => _toggleBluetoothSco(),
                  activeTrackColor: PgColors.accentBlue,
                  activeThumbColor: PgColors.white,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _bluetoothHeadsetConnected 
                ? (_bluetoothScoEnabled 
                    ? 'Capturing SCO audio (headset required)'
                    : 'Enable to capture SCO audio')
                : 'Connect Bluetooth headset for SCO audio',
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.lightBlue,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShizukuControl() {
    final state = _shizukuCapture.currentState;
    final canEnable = state == ShizukuState.granted;
    final isFailing = state == ShizukuState.captureFailing;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Shizuku Audio',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PgColors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFailing 
                              ? PgColors.crit.withValues(alpha: 0.2)
                              : PgColors.dspAccent.withValues(alpha: 0.2),
                          border: Border.all(
                            color: isFailing ? PgColors.crit : PgColors.dspAccent,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(PgRadius.bar),
                        ),
                        child: Text(
                          isFailing ? 'FAILING' : 'EXPERIMENTAL',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: isFailing ? PgColors.crit : PgColors.dspAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _shizukuStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: isFailing ? PgColors.crit : PgColors.mediumBlue,
                    ),
                  ),
                  if (_shizukuCapture.isCapturing) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Health: ${_shizukuCapture.bypassHealth}, Step: ${_shizukuCapture.fallbackStep}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: PgColors.lightBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Non-zero: ${_shizukuCapture.nonZeroPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        color: PgColors.lightBlue,
                      ),
                    ),
                  ],
                ],
              ),
              if (canEnable)
                Switch(
                  value: _shizukuEnabled,
                  onChanged: (value) => _toggleShizuku(),
                  activeTrackColor: PgColors.dspAccent,
                  activeThumbColor: PgColors.white,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getShizukuDescription(state),
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.lightBlue,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getShizukuDescription(ShizukuState state) {
    switch (state) {
      case ShizukuState.notInstalled:
        return 'Install Shizuku from F-Droid/GitHub, enable wireless debugging';
      case ShizukuState.notRunning:
        return 'Start Shizuku app and grant permission';
      case ShizukuState.permissionNeeded:
        return 'Tap switch to request Shizuku permission';
      case ShizukuState.granted:
        return 'Cally-like bypass ready. Uses shell UID with WrappedShellContext for voice capture';
      case ShizukuState.active:
        return 'Capture active. Health: ${_shizukuCapture.bypassHealth}, Step: ${_shizukuCapture.fallbackStep}';
      case ShizukuState.captureFailing:
        return 'FAILURE: Silent buffers detected. ROM blocks voice capture';
    }
  }
  
  Widget _buildPriorityRecordingControl() {
    final method = _currentRecordingMethod;
    final priority = _priorityRecording.currentPriority;
    final isRecording = _priorityRecording.isRecording;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Smart Recording',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PgColors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: PgColors.accentBlue.withValues(alpha: 0.2),
                          border: Border.all(
                            color: PgColors.accentBlue,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(PgRadius.bar),
                        ),
                        child: const Text(
                          'AUTO',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: PgColors.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _priorityRecordingStatus,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                  ),
                  if (isRecording) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Method: ${_priorityRecording.getMethodDisplayName(method)} (Priority: $priority)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: PgColors.lightBlue,
                      ),
                    ),
                  ],
                ],
              ),
              Switch(
                value: _priorityRecordingEnabled,
                onChanged: (value) => _togglePriorityRecording(),
                activeTrackColor: PgColors.accentBlue,
                activeThumbColor: PgColors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getPriorityRecordingDescription(method),
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.lightBlue,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPriorityRecordingDescription(RecordingMethod method) {
    switch (method) {
      case RecordingMethod.none:
        return 'Auto-selects best recording method: Cally → VoIP → Accessibility → Bluetooth → Hardware';
      case RecordingMethod.cally:
        return 'Using Cally (Shizuku shell UID) - Primary method, no speakerphone needed';
      case RecordingMethod.voip:
        return 'Using VoIP APIs (Vapi/Plivo) - First fallback for VoIP calls';
      case RecordingMethod.accessibility:
        return 'Using Accessibility + Speakerphone - Second fallback, speakerphone auto-enabled';
      case RecordingMethod.bluetooth:
        return 'Using Bluetooth SCO - Third fallback, requires headset';
      case RecordingMethod.hardware:
        return 'Hardware device recommended - Last resort for perfect recording';
    }
  }
  
  Widget _buildScamDetectionDemo() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Backend AI Integration',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PgColors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: PgColors.accentBlue.withValues(alpha: 0.2),
                          border: Border.all(
                            color: PgColors.accentBlue,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(PgRadius.bar),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: PgColors.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time scam detection using backend AI',
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScamDetectionDemo(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PgColors.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'Open Demo',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocalScamDetectionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PgColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'Local Detection',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Integrates with PhaseGuard backend for AI-powered scam detection. '
            'Uses accessibility + speakerphone for audio capture and streams to backend for real-time analysis.',
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.lightBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallItem(CallRecord call) {
    final riskColor = _getRiskColor(call.riskLevel);
    final statusLabel = _getStatusLabel(call.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.caller,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PgColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${call.time} • ${call.duration}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: PgColors.mediumBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    border: Border.all(color: riskColor, width: 1),
                    borderRadius: BorderRadius.circular(PgRadius.bar),
                  ),
                  child: Text(
                    call.riskLevel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: riskColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: riskColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PgColors.lightBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'low':
        return PgColors.safe;
      case 'medium':
        return PgColors.warn;
      case 'high':
        return PgColors.crit;
      default:
        return PgColors.mediumBlue;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'blocked':
        return 'Blocked & Reported';
      case 'safe':
        return 'Safe Call';
      case 'monitored':
        return 'Monitored';
      default:
        return 'Unknown';
    }
  }
}

class CallRecord {
  final String id;
  final String caller;
  final String time;
  final String duration;
  final String riskLevel;
  final String status;

  CallRecord({
    required this.id,
    required this.caller,
    required this.time,
    required this.duration,
    required this.riskLevel,
    required this.status,
  });
}