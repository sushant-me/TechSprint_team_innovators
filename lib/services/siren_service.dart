import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:vibration/vibration.dart'; // Ideally add this package

enum SirenMode {
  panic,    // Classic "Wail" (Long cycles) - Good for attracting attention
  pulse,    // Fast "Yelp" (Short cycles) - Good for location finding
  stealth,  // Vibration only - Good for hiding
  disorient // High frequency strobe
}

class SonicDefenseSystem {
  // Singleton Pattern
  static final SonicDefenseSystem _instance = SonicDefenseSystem._internal();
  factory SonicDefenseSystem() => _instance;
  SonicDefenseSystem._internal();

  final AudioPlayer _player = AudioPlayer();
  
  // State Tracking
  bool _isActive = false;
  SirenMode _currentMode = SirenMode.panic;
  Timer? _hapticTimer;

  // Stream for UI (shows current mode/activity)
  final StreamController<SirenMode?> _statusController = StreamController.broadcast();
  Stream<SirenMode?> get statusStream => _statusController.stream;

  /// 1. SETUP: Configure the Audio Session for WAR
  Future<void> initialize() async {
    // This is the "Wow" part: We force the audio to the ALARM stream.
    // This often bypasses "Silent Mode" and "Do Not Disturb".
    final AudioContext audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: [
          AVAudioSessionOptions.duckOthers, // Lower volume of other apps
          AVAudioSessionOptions.mixWithOthers,
        ],
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm, // CRITICAL: Identify as Alarm
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    );

    await AudioPlayer.global.setAudioContext(audioContext);
    await _player.setReleaseMode(ReleaseMode.loop);
  }

  /// 2. ENGAGE: Starts the acoustic and haptic attack
  Future<void> engage({SirenMode mode = SirenMode.panic}) async {
    if (_isActive && _currentMode == mode) return; // Already running this mode
    
    _isActive = true;
    _currentMode = mode;
    _statusController.add(mode);

    try {
      // A. Stop any existing output to switch cleanly
      await _player.stop();
      _hapticTimer?.cancel();

      if (mode == SirenMode.stealth) {
        // Silent Mode: Haptics only
        _startHapticPattern(500); // Slow, heavy pulse
      } else {
        // Audible Mode
        String assetPath = _getAssetForMode(mode);
        await _player.setSource(AssetSource(assetPath));
        await _player.setVolume(1.0); // Max Volume
        await _player.resume();
        
        // Sync Haptics to the Sound
        _startHapticPattern(_getHapticDuration(mode));
      }
    } catch (e) {
      print("🚨 SONIC FAILURE: $e");
      // Fallback: If audio fails, at least vibrate
      _startHapticPattern(200); 
    }
  }

  /// 3. DISENGAGE: Silence everything
  Future<void> disengage() async {
    _isActive = false;
    _statusController.add(null);
    
    // Fade out effect (Optional polish)
    await _player.setVolume(0); 
    await Future.delayed(const Duration(milliseconds: 200));
    
    await _player.stop();
    _hapticTimer?.cancel();
    Vibration.cancel(); // Stop physical motor
  }

  // --- INTERNAL ENGINES ---

  String _getAssetForMode(SirenMode mode) {
    // You need these 3 files in assets/
    switch (mode) {
      case SirenMode.pulse: return 'siren_yelp.mp3'; // Fast chirp
      case SirenMode.disorient: return 'high_freq.mp3'; // Annoying 15kHz
      case SirenMode.panic: 
      default: return 'siren_wail.mp3'; // Standard police wail
    }
  }

  int _getHapticDuration(SirenMode mode) {
    switch (mode) {
      case SirenMode.pulse: return 200; // Fast vibration
      case SirenMode.disorient: return 100; // Strobe vibration
      case SirenMode.panic: return 1000; // Long vibration
      default: return 500;
    }
  }

  void _startHapticPattern(int durationMs) {
    _hapticTimer?.cancel();
    
    // Create a loop for vibration
    _hapticTimer = Timer.periodic(Duration(milliseconds: durationMs * 2), (timer) async {
      if (!_isActive) {
        timer.cancel();
        return;
      }
      
      // Check if device has custom vibration hardware
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: durationMs, amplitude: 255); // Max power
      } else {
        // Fallback for older phones
        HapticFeedback.heavyImpact();
      }
    });
  }
}
