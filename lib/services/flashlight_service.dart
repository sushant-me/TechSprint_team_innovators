import 'dart:async';
import 'package:torch_light/torch_light.dart';

enum LightMode { 
  sos,            // Standard International Distress
  tacticalStrobe, // 15Hz Disorienting Flash
  ecoBeacon,      // Low power location marker
  customMessage   // Transmits text via Morse
}

class OpticalSignalingSystem {
  bool _isActive = false;
  
  // Full International Morse Code Standard
  static const Map<String, String> _morseMap = {
    'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
    'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
    'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
    'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
    'Y': '-.--', 'Z': '--..', '1': '.----', '2': '..---', '3': '...--',
    '4': '....-', '5': '.....', '6': '-....', '7': '--...', '8': '---..',
    '9': '----.', '0': '-----', '.': '.-.-.-', ',': '--..--'
  };

  // Standard Timing Units (WPM ~ 8)
  static const int _unitMs = 150; 
  static const int _dotMs = _unitMs;
  static const int _dashMs = _unitMs * 3;
  static const int _intraCharGap = _unitMs;     // Between parts of a letter
  static const int _interCharGap = _unitMs * 3; // Between letters
  static const int _wordGap = _unitMs * 7;      // Between words

  /// Master Control Switch
  Future<void> engageSystem({
    LightMode mode = LightMode.sos, 
    String? customMessage
  }) async {
    // 1. SAFETY: Kill any previous signal first
    if (_isActive) await disengage();
    
    // 2. CHECK HARDWARE
    try {
      if (!await TorchLight.isTorchAvailable()) throw "Hardware Not Found";
    } catch (e) {
      print("❌ OPTIC FAILURE: $e");
      return;
    }

    _isActive = true;
    print("🔦 OPTICAL SYSTEM ENGAGED: ${mode.name.toUpperCase()}");

    // 3. EXECUTE PROTOCOL
    try {
      switch (mode) {
        case LightMode.sos:
          await _transmitMorseLoop("SOS");
          break;
        case LightMode.customMessage:
          if (customMessage != null && customMessage.isNotEmpty) {
            await _transmitMorseLoop(customMessage);
          }
          break;
        case LightMode.tacticalStrobe:
          await _runTacticalStrobe();
          break;
        case LightMode.ecoBeacon:
          await _runEcoBeacon();
          break;
      }
    } catch (e) {
      print("⚠️ SIGNAL INTERRUPTED: $e");
    } finally {
      // Ensure light is off if loop crashes
      if (_isActive) await disengage(); 
    }
  }

  /// HARD SHUTDOWN
  Future<void> disengage() async {
    _isActive = false;
    // Wait a tiny bit for any active delay to clear
    await Future.delayed(const Duration(milliseconds: 100)); 
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
    print("🔦 OPTICAL SYSTEM DISENGAGED");
  }

  // --- ENGINES ---

  /// Translates Text -> Light -> Loop
  Future<void> _transmitMorseLoop(String message) async {
    final cleanMsg = message.toUpperCase().trim();
    
    while (_isActive) {
      for (int i = 0; i < cleanMsg.length; i++) {
        if (!_isActive) break;

        String char = cleanMsg[i];
        
        // Handle Spaces (Word Gaps)
        if (char == ' ') {
          await Future.delayed(const Duration(milliseconds: _wordGap));
          continue;
        }

        // Handle Characters
        String? sequence = _morseMap[char];
        if (sequence != null) {
          await _flashSequence(sequence);
          // Gap between letters
          await Future.delayed(const Duration(milliseconds: _interCharGap));
        }
      }
      // Gap before repeating message
      await Future.delayed(const Duration(milliseconds: _wordGap * 2));
    }
  }

  /// Flashes a single character (e.g., ".-")
  Future<void> _flashSequence(String sequence) async {
    for (int i = 0; i < sequence.length; i++) {
      if (!_isActive) return;

      int duration = (sequence[i] == '.') ? _dotMs : _dashMs;

      await TorchLight.enableTorch();
      await Future.delayed(Duration(milliseconds: duration));
      
      await TorchLight.disableTorch();
      await Future.delayed(const Duration(milliseconds: _intraCharGap));
    }
  }

  /// 15Hz High-Intensity Strobe
  /// Used for visibility against aircraft or confusing attackers
  Future<void> _runTacticalStrobe() async {
    while (_isActive) {
      await TorchLight.enableTorch();
      await Future.delayed(const Duration(milliseconds: 33)); // ~15Hz
      await TorchLight.disableTorch();
      await Future.delayed(const Duration(milliseconds: 33));
    }
  }

  /// Power Saving "Heartbeat" (1 Flash every 3 sec)
  /// Good for nights when you are lost but stationary
  Future<void> _runEcoBeacon() async {
    while (_isActive) {
      await TorchLight.enableTorch();
      await Future.delayed(const Duration(milliseconds: 50)); // Short blip
      await TorchLight.disableTorch();
      await Future.delayed(const Duration(seconds: 3)); // Long sleep
    }
  }
}
