import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tflite_audio/tflite_audio.dart';

class AudioDetector {
  // CONFIGURATION
  // Matches the model you trained in Teachable Machine
  static const String modelPath = 'assets/soundclassifier.tflite';
  static const String labelPath = 'assets/labels.txt';
  static const String triggerLabel =
      'SOS'; // MUST match your Class Name exactly
  static const double confidenceThreshold = 0.95; // 95% sure before triggering

  StreamSubscription? _audioSubscription;
  bool _isListening = false;

  // The function to call when SOS is heard
  final VoidCallback onSosDetected;

  AudioDetector({required this.onSosDetected});

  Future<void> startListening() async {
    if (_isListening) return;

    try {
      // 1. Load the Model
      await TfliteAudio.loadModel(
        model: modelPath,
        label: labelPath,
        numThreads: 1,
        isAsset: true,
        inputType: 'rawAudio',
      );

      // 2. Start the Stream
      // These settings are optimized for Teachable Machine models
      _audioSubscription = TfliteAudio.startAudioRecognition(
        sampleRate: 44100,
        bufferSize: 22016,
        numOfInferences: 99999, // Infinite loop
      ).listen(_handleResult);

      _isListening = true;
      print("GHOST SIGNAL EARS: Active & Listening for '$triggerLabel'...");
    } catch (e) {
      print("Error starting Audio Detector: $e");
    }
  }

  void _handleResult(Map<dynamic, dynamic> event) {
    // The event returns a map like: {"recognitionResult": "SOS 0.98"}

    // Parse the result
    String rawResult = event["recognitionResult"].toString();
    // Example format: "SOS 0.99" or "Background Noise 0.80"

    // Check if it's our trigger word
    if (rawResult.startsWith(triggerLabel)) {
      // Extract confidence score
      // "SOS 0.99" -> 0.99
      double confidence = double.tryParse(rawResult.split(" ").last) ?? 0.0;

      if (confidence > confidenceThreshold) {
        print("CRITICAL: TRIGGER HEARD! ($rawResult)");
        stopListening(); // Stop listening so we don't trigger twice
        onSosDetected(); // FIRE THE ALARM
      }
    }
  }

  void stopListening() {
    _audioSubscription?.cancel();
    TfliteAudio.stopAudioRecognition();
    _isListening = false;
  }
}
