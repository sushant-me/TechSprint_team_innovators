import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tflite_audio/tflite_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioDetector {
  StreamSubscription? _audioSubscription;
  final VoidCallback onSosDetected;
  bool _isListening = false;
  double _threshold = 0.60;

  AudioDetector({required this.onSosDetected});

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;
    final prefs = await SharedPreferences.getInstance();
    _threshold = prefs.getDouble('voice_threshold') ?? 0.60;
    _listenLoop();
  }

  void _listenLoop() async {
    if (!_isListening) return;
    try {
      await _audioSubscription?.cancel();
      await TfliteAudio.loadModel(
        model: 'assets/soundclassifier.tflite',
        label: 'assets/labels.txt',
        numThreads: 1,
        isAsset: true,
        inputType: 'rawAudio',
      );

      _audioSubscription = TfliteAudio.startAudioRecognition(
        sampleRate: 44100,
        bufferSize: 22016,
        numOfInferences: 99999,
      ).listen((event) {
        String result = event["recognitionResult"].toString().toLowerCase();
        double conf = double.tryParse(result.split(" ").last) ?? 0.0;
        if ((result.contains("bachau") || result.contains("help")) &&
            conf >= _threshold) {
          onSosDetected();
        }
      }, onError: (e) => _restart(), onDone: _restart);
    } catch (e) {
      _restart();
    }
  }

  void _restart() {
    if (_isListening) Future.delayed(const Duration(seconds: 1), _listenLoop);
  }

  void stopListening() {
    _isListening = false;
    _audioSubscription?.cancel();
  }
}
