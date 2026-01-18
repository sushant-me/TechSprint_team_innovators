import 'dart:async';
import 'dart:math';
import 'package:torch_light/torch_light.dart';

enum LightMode { 
  sos,            // Standard International Distress
  tacticalStrobe, // 15Hz Disorienting Flash
  ecoBeacon,      // Low power location marker
  panicBurst,     // Randomized chaos pattern (High Visibility)
  customMessage   // Transmits text via Morse
}

class FlashlightService {
  // --- STATE ---
  bool _isActive = false;
  int _unitMs = 100; // Default speed (approx 12 WPM)

  // --- STREAMS (THE WOW FACTOR) ---
  // 1. Syncs the UI icon with the real flashlight
  final _lightStateCtrl = StreamController<bool>.broadcast();
  Stream<bool> get onLightStateChanged => _lightStateCtrl.stream;

  // 2. Tells the UI what letter is currently being sent
  final _charCtrl = StreamController<String>.broadcast();
  Stream<String> get currentCharacterStream => _charCtrl.stream;

  // --- MORSE DICTIONARY ---
  static const Map<String, String> _morseMap = {
    'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
    'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
    'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
    'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
    'Y': '-.--', 'Z': '--..', '1': '.----', '2': '..---', '3': '...--',
    '4': '....-', '5': '.....', '6': '-....', '7': '--...', '8': '---..',
    '9': '----.', '0': '-----', '.': '.-.-.-', ',': '--..--', '?': '..--..',
    '/': '-..-.', '@': '.--.-.'
  };

  // --- CONFIGURATION ---
  
  /// Adjust speed. Higher WPM = Faster Flashing.
  /// Standard SOS is usually 8-12 WPM.
  void setTransmissionSpeed(int wpm) {
    // Standard logic: T = 1200 / WPM
    _unitMs = (1200 / wpm.clamp(5, 30)).round(); 
  }

  /// Master Control Switch
  Future<void> engageSystem({
    LightMode mode = LightMode.sos, 
    String? customMessage
  }) async {
    // 1. CLEANUP
    if (_isActive) await stopStrobe();
    
    // 2. HARDWARE CHECK
    try {
      bool hasTorch = await TorchLight.isTorchAvailable();
      if (!hasTorch) throw "Hardware Missing";
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
        case LightMode.panicBurst:
          await _runPanicBurst();
          break;
        case LightMode.ecoBeacon:
          await _runEcoBeacon();
          break;
      }
    } catch (e) {
      print("⚠️ SIGNAL INTERRUPTED: $e");
    } finally {
      // Failsafe: Ensure light is OFF if loop crashes or finishes
      if (_isActive) await stopStrobe(); 
    }
  }

  /// HARD SHUTDOWN
  Future<void> stopStrobe() async {
    _isActive = false;
    _lightStateCtrl.add(false); // Notify UI
    _charCtrl.add(""); // Clear Text
    
    // Wait for any active delay to clear
    await Future.delayed(const Duration(milliseconds: 150)); 
    
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
    print("🔦 OPTICAL SYSTEM DISENGAGED");
  }

  // --- SIGNAL ENGINES ---

  /// Translates Text -> Light -> Loop
  Future<void> _transmitMorseLoop(String message) async {
    final cleanMsg = message.toUpperCase().trim();
    
    while (_isActive) {
      for (int i = 0; i < cleanMsg.length; i++) {
        if (!_isActive) break;

        String char = cleanMsg[i];
        
        // Notify UI
        _charCtrl.add(char);

        // Handle Spaces (Word Gaps)
        if (char == ' ') {
          await Future.delayed(Duration(milliseconds: _unitMs * 7));
          continue;
        }

        // Handle Characters
        String? sequence = _morseMap[char];
        if (sequence != null) {
          await _flashSequence(sequence);
          // Gap between letters (3 units)
          await Future.delayed(Duration(milliseconds: _unitMs * 3));
        }
      }
      
      // Notify UI of loop reset
      _charCtrl.add("WAIT...");
      // Gap before repeating message (7 units)
      await Future.delayed(Duration(milliseconds: _unitMs * 7));
    }
  }

  /// Flashes a single character sequence (e.g., ".-")
  Future<void> _flashSequence(String sequence) async {
    for (int i = 0; i < sequence.length; i++) {
      if (!_isActive) return;

      // Determine duration: Dot = 1 unit, Dash = 3 units
      int duration = (sequence[i] == '.') ? _unitMs : (_unitMs * 3);

      await _setLight(true);
      await Future.delayed(Duration(milliseconds: duration));
      
      await _setLight(false);
      // Gap between parts of same letter (1 unit)
      await Future.delayed(Duration(milliseconds: _unitMs));
    }
  }

  /// 15Hz High-Intensity Strobe
  /// Used for visibility against aircraft or confusing attackers
  Future<void> _runTacticalStrobe() async {
    _charCtrl.add("STROBE");
    while (_isActive) {
      await _setLight(true);
      await Future.delayed(const Duration(milliseconds: 33)); // ~15Hz
      await _setLight(false);
      await Future.delayed(const Duration(milliseconds: 33));
    }
  }

  /// Randomized burst pattern.
  /// Harder for the brain to filter out than a steady strobe.
  Future<void> _runPanicBurst() async {
    _charCtrl.add("PANIC");
    final random = Random();
    while (_isActive) {
      // Rapid random flashes
      int pulses = random.nextInt(5) + 3; // 3 to 8 flashes
      for(int i=0; i<pulses; i++) {
         await _setLight(true);
         await Future.delayed(const Duration(milliseconds: 40));
         await _setLight(false);
         await Future.delayed(const Duration(milliseconds: 40));
      }
      // Random pause
      await Future.delayed(Duration(milliseconds: random.nextInt(500) + 200));
    }
  }

  /// Power Saving "Heartbeat" (1 Flash every 5 sec)
  Future<void> _runEcoBeacon() async {
    _charCtrl.add("BEACON");
    while (_isActive) {
      await _setLight(true);
      await Future.delayed(const Duration(milliseconds: 100)); // Short blip
      await _setLight(false);
      await Future.delayed(const Duration(seconds: 5)); // Long sleep
    }
  }

  // Helper to sync Hardware + UI Stream
  Future<void> _setLight(bool on) async {
    if (!_isActive) return;
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      _lightStateCtrl.add(on); // Update UI
    } catch (e) {
      // Ignore rapid toggle errors
    }
  }
}
