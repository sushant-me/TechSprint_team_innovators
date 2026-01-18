import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_audio/tflite_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single moment of AI listening
class AudioInference {
  final String label;
  final double confidence;
  final int inferenceTime;

  AudioInference({
    required this.label, 
    required this.confidence, 
    required this.inferenceTime
  });

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)}%)';
}

class AudioSentinel {
  // --- CONFIGURATION ---
  static const String _modelPath = 'assets/soundclassifier.tflite';
  static const String _labelPath = 'assets/labels.txt';
  static const int _sampleRate = 44100; // Standard High-Res
  static const int _bufferSize = 11008; // Optimized for lower latency
  static const int _coolDownMs = 3000;  // Don't trigger SOS twice in 3 seconds

  // --- STATE ---
  StreamSubscription? _audioSubscription;
  bool _isListening = false;
  double _sensitivity = 0.60;
  DateTime? _lastTriggerTime;
  
  // --- STREAMS (The "Wow" Factor) ---
  // Broadcasts EVERYTHING the AI hears. Use this to animate a UI graph!
  final _inferenceStreamCtrl = StreamController<AudioInference>.broadcast();
  Stream<AudioInference> get liveInferenceStream => _inferenceStreamCtrl.stream;

  // The actual alarm trigger
  final VoidCallback onSosDetected;

  AudioSentinel({required this.onSosDetected});

  /// Initializes the neural network and ear.
  Future<void> armSentinel() async {
    if (_isListening) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _sensitivity = prefs.getDouble('voice_threshold') ?? 0.60;
      
      debugPrint("🛡️ SENTINEL: Loading Neural Model...");
      await TfliteAudio.loadModel(
        model: _modelPath,
        label: _labelPath,
        numThreads: 2, // Use 2 threads for smoother UI (if device supports)
        isAsset: true,
        inputType: 'rawAudio',
      );

      _isListening = true;
      _startMicrophoneStream();
      debugPrint("🛡️ SENTINEL: Armed and Listening.");
    } catch (e) {
      debugPrint("❌ SENTINEL INIT ERROR: $e");
      _attemptRecovery();
    }
  }

  void _startMicrophoneStream() {
    if (!_isListening) return;

    // Reset stream
    _audioSubscription?.cancel();

    _audioSubscription = TfliteAudio.startAudioRecognition(
      sampleRate: _sampleRate,
      bufferSize: _bufferSize,
      numOfInferences: 99999,
    ).listen(
      _processAudioFrame,
      onError: (e) {
        debugPrint("⚠️ Mic Stream Error: $e");
        _attemptRecovery();
      },
      onDone: () => _attemptRecovery(),
    );
  }

  void _processAudioFrame(Map<dynamic, dynamic> event) {
    // 1. Safe Parsing
    final String rawResult = event["recognitionResult"]?.toString() ?? "";
    // Expected format: "label 0.85" or just "label" depending on model output
    
    String label = "noise";
    double confidence = 0.0;
    int time = event["inferenceTime"] ?? 0;

    // Robust splitter that handles different model output formats
    final parts = rawResult.trim().split(" ");
    if (parts.isNotEmpty) {
      // If last part is a number, it's confidence. Otherwise it's just a label.
      final possibleConf = double.tryParse(parts.last);
      if (possibleConf != null) {
        confidence = possibleConf;
        label = parts.sublist(0, parts.length - 1).join(" ").toLowerCase();
      } else {
        label = rawResult.toLowerCase();
        confidence = 1.0; // Binary classification assumption
      }
    }

    // 2. Broadcast for UI Visualization
    final inference = AudioInference(
      label: label, 
      confidence: confidence, 
      inferenceTime: time
    );
    _inferenceStreamCtrl.add(inference);

    // 3. Trigger Logic with Debounce
    if (_isThreatDetected(label) && confidence >= _sensitivity) {
      _triggerAlarm(inference);
    }
  }

  bool _isThreatDetected(String label) {
    return label.contains("bachau") || 
           label.contains("help") || 
           label.contains("scream"); // Added scream support if your model has it
  }

  void _triggerAlarm(AudioInference inference) {
    final now = DateTime.now();
    
    // Check Cool-down
    if (_lastTriggerTime != null && 
        now.difference(_lastTriggerTime!).inMilliseconds < _coolDownMs) {
      return; // Too soon, ignore.
    }

    debugPrint("🚨 SOS TRIGGERED: ${inference.label} @ ${(inference.confidence*100).toInt()}%");
    _lastTriggerTime = now;
    onSosDetected();
  }

  void _attemptRecovery() {
    if (!_isListening) return;
    debugPrint("♻️ SENTINEL: Restarting Ear...");
    // Slight delay to prevent CPU thrashing if mic is broken
    Future.delayed(const Duration(milliseconds: 1500), _startMicrophoneStream);
  }

  void disarm() {
    debugPrint("🛡️ SENTINEL: Disarmed.");
    _isListening = false;
    _audioSubscription?.cancel();
    _inferenceStreamCtrl.close();
  }
}
