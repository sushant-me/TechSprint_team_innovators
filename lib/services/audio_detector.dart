import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_audio/tflite_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a momentary slice of AI analysis
class AudioInference {
  final String label;          // What was heard? (e.g., "help", "background")
  final double confidence;     // How sure is the AI? (0.0 - 1.0)
  final double energyLevel;    // How loud was it? (0.0 - 1.0) - Used for UI Visuals
  final int inferenceTime;     // How fast did the brain work? (ms)

  AudioInference({
    required this.label, 
    required this.confidence, 
    required this.inferenceTime,
    this.energyLevel = 0.0,
  });

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)}%)';
}

class AudioSentinel {
  // --- CONFIGURATION ---
  static const String _modelPath = 'assets/soundclassifier.tflite';
  static const String _labelPath = 'assets/labels.txt';
  static const int _sampleRate = 44100; 
  static const int _bufferSize = 11008; 
  static const int _coolDownMs = 3000;  

  // --- STATE ---
  StreamSubscription? _audioSubscription;
  Timer? _simulationTimer; // For testing without real hardware
  bool _isListening = false;
  double _sensitivity = 0.60;
  DateTime? _lastTriggerTime;
  bool _isSimulationMode = false;

  // --- STREAMS ---
  // The UI listens to this to animate graphs/circles
  final _inferenceStreamCtrl = StreamController<AudioInference>.broadcast();
  Stream<AudioInference> get liveInferenceStream => _inferenceStreamCtrl.stream;

  // The actual alarm trigger callback
  final VoidCallback onSosDetected;

  AudioSentinel({required this.onSosDetected});

  /// 1. ARM THE SYSTEM
  /// Tries to load the real neural network. If it fails (e.g., assets missing),
  /// it gracefully degrades to "Simulation Mode" so you can still dev the UI.
  Future<void> armSentinel() async {
    if (_isListening) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _sensitivity = prefs.getDouble('voice_threshold') ?? 0.60;
      
      debugPrint("🛡️ SENTINEL: Loading Neural Model...");
      await TfliteAudio.loadModel(
        model: _modelPath,
        label: _labelPath,
        numThreads: 2, 
        isAsset: true,
        inputType: 'rawAudio',
      );

      _isListening = true;
      _isSimulationMode = false;
      _startMicrophoneStream();
      debugPrint("🛡️ SENTINEL: Armed and Listening (Hardware Mode).");

    } catch (e) {
      debugPrint("⚠️ SENTINEL HARDWARE FAILURE: $e");
      debugPrint("⚠️ SWITCHING TO SIMULATION PROTOCOL.");
      _startSimulationMode();
    }
  }

  /// 2. REAL MICROPHONE STREAM
  void _startMicrophoneStream() {
    if (!_isListening) return;

    _audioSubscription?.cancel();

    _audioSubscription = TfliteAudio.startAudioRecognition(
      sampleRate: _sampleRate,
      bufferSize: _bufferSize,
      numOfInferences: 99999, // Run forever
    ).listen(
      _processAudioFrame,
      onError: (e) {
        debugPrint("⚠️ Mic Stream Error: $e");
        // Don't crash app, just switch to sim or retry
        _attemptRecovery(); 
      },
      onDone: () => _attemptRecovery(),
    );
  }

  /// 3. THE BRAIN (Processing Logic)
  void _processAudioFrame(Map<dynamic, dynamic> event) {
    // A. Parse Data
    final String rawResult = event["recognitionResult"]?.toString() ?? "";
    int time = event["inferenceTime"] ?? 0;
    
    String label = "background";
    double confidence = 0.0;

    // Robust splitting (handles "help 0.98" vs "help")
    final parts = rawResult.trim().split(" ");
    if (parts.isNotEmpty) {
      final possibleConf = double.tryParse(parts.last);
      if (possibleConf != null) {
        confidence = possibleConf;
        label = parts.sublist(0, parts.length - 1).join(" ").toLowerCase();
      } else {
        label = rawResult.toLowerCase();
        confidence = 1.0; 
      }
    }

    // B. Create Inference Object
    // NOTE: Since TFLiteAudio doesn't give raw dB levels easily, 
    // we simulate "Energy" based on confidence to make the UI look reactive.
    double simulatedEnergy = (confidence > 0.3) ? confidence : (Random().nextDouble() * 0.1);

    final inference = AudioInference(
      label: label, 
      confidence: confidence, 
      inferenceTime: time,
      energyLevel: simulatedEnergy 
    );

    // C. Broadcast to UI
    _inferenceStreamCtrl.add(inference);

    // D. Check for Threat
    if (_isThreatDetected(label) && confidence >= _sensitivity) {
      _triggerAlarm(inference);
    }
  }

  bool _isThreatDetected(String label) {
    return label.contains("bachau") || 
           label.contains("help") || 
           label.contains("scream"); 
  }

  void _triggerAlarm(AudioInference inference) {
    final now = DateTime.now();
    
    // Cool-down check
    if (_lastTriggerTime != null && 
        now.difference(_lastTriggerTime!).inMilliseconds < _coolDownMs) {
      return; 
    }

    debugPrint("🚨 SOS TRIGGERED: ${inference.label} @ ${(inference.confidence*100).toInt()}%");
    _lastTriggerTime = now;
    onSosDetected(); // Call the UI callback
  }

  /// 4. RECOVERY & SIMULATION
  void _attemptRecovery() {
    if (!_isListening) return;
    debugPrint("♻️ SENTINEL: Restarting Ear...");
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isSimulationMode) {
        _startSimulationMode();
      } else {
        _startMicrophoneStream();
      }
    });
  }

  /// Fakes a microphone stream for testing UI when no model is present
  void _startSimulationMode() {
    _isListening = true;
    _isSimulationMode = true;
    _simulationTimer?.cancel();
    
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }

      // Randomly decide if we hear noise or a trigger
      final random = Random();
      bool trigger = random.nextDouble() > 0.90; // 10% chance to trigger
      
      final inf = AudioInference(
        label: trigger ? "help" : "background_noise", 
        confidence: trigger ? 0.85 : random.nextDouble() * 0.3, 
        inferenceTime: 120,
        energyLevel: random.nextDouble() // Random energy for UI visuals
      );

      _inferenceStreamCtrl.add(inf);

      if (trigger) {
        _triggerAlarm(inf);
      }
    });
  }

  /// 5. SHUTDOWN
  void disarm() {
    debugPrint("🛡️ SENTINEL: Disarmed.");
    _isListening = false;
    _audioSubscription?.cancel();
    _simulationTimer?.cancel();
    TfliteAudio.stopAudioRecognition();
    // Don't close the stream controller here if you plan to re-arm the sentinel later.
    // If this is a one-time use object, then close it.
  }
}
