import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';

class VideoDeepfakeDetector {
  late final FaceDetector _faceDetector;
  
  // History buffers for temporal analysis (to detect static 2D photos)
  final List<double> _eyeOpenHistory = [];
  final List<double> _headAngleXHistory = [];
  final List<double> _headAngleYHistory = [];
  final int _maxHistoryLength = 15; // Track last 15 frames

  VideoDeepfakeDetector() {
    // Initialize face detector with options for liveness (head euler angles)
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// Calculates variance of a list of numbers
  double _calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSq = values.fold(0.0, (acc, val) => acc + pow(val - mean, 2));
    return sumSq / (values.length - 1);
  }

  /// Process a video frame locally to detect liveness/spoofing
  Future<Map<String, dynamic>> processFrame(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      
      // Calculate chain-of-custody hash (SHA-256)
      final bytes = await imageFile.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      bool faceDetected = faces.isNotEmpty;
      bool isSpoof = false;
      double livenessScore = 0.0;
      String spoofReason = "";

      if (faceDetected) {
        final face = faces.first;
        
        // 1. Update temporal history
        if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
          double avgEye = (face.leftEyeOpenProbability! + face.rightEyeOpenProbability!) / 2;
          _eyeOpenHistory.add(avgEye);
          livenessScore = avgEye;
        }
        
        if (face.headEulerAngleX != null) _headAngleXHistory.add(face.headEulerAngleX!);
        if (face.headEulerAngleY != null) _headAngleYHistory.add(face.headEulerAngleY!);

        // Maintain buffer sizes
        if (_eyeOpenHistory.length > _maxHistoryLength) _eyeOpenHistory.removeAt(0);
        if (_headAngleXHistory.length > _maxHistoryLength) _headAngleXHistory.removeAt(0);
        if (_headAngleYHistory.length > _maxHistoryLength) _headAngleYHistory.removeAt(0);

        // 2. Deepfake / 2D Photo Spoof Detection Logic
        
        // Check A: Perfectly zero Euler angles (often means a static digital photo is held up)
        if (face.headEulerAngleX == 0.0 && face.headEulerAngleY == 0.0 && face.headEulerAngleZ == 0.0) {
           isSpoof = true;
           spoofReason = "Unnatural perfectly static head angles (0.0)";
        }
        
        // Check B: Temporal Variance (if we have enough frames, a real human MUST move slightly)
        if (_eyeOpenHistory.length >= 10) {
           double eyeVariance = _calculateVariance(_eyeOpenHistory);
           double headXVariance = _calculateVariance(_headAngleXHistory);
           double headYVariance = _calculateVariance(_headAngleYHistory);

           // A real human cannot keep their head and eyes microscopically still for 10 frames
           if (eyeVariance < 0.0001 && headXVariance < 0.001 && headYVariance < 0.001) {
              isSpoof = true;
              spoofReason = "Zero temporal variance detected (2D Photo/Screen Spoof)";
           }
        }
      }

      return {
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'sha256_hash': hash,
        'face_detected': faceDetected,
        'is_spoof': isSpoof,
        'spoof_reason': spoofReason,
        'liveness_score': livenessScore,
        'faces_count': faces.length,
      };

    } catch (e) {
      print("Error processing video frame locally: \$e");
      return {
        'error': e.toString(),
        'face_detected': false,
        'is_spoof': false,
      };
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
