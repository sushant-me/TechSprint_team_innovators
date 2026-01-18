import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avatar_glow/avatar_glow.dart';

// --- MAIN SCREEN ---

class SafetyCheckScreen extends StatefulWidget {
  final String triggerCause; // e.g., "Earthquake Detected", "Fall Detected"
  const SafetyCheckScreen({super.key, required this.triggerCause});

  @override
  State<SafetyCheckScreen> createState() => _SafetyCheckScreenState();
}

class _SafetyCheckScreenState extends State<SafetyCheckScreen> with TickerProviderStateMixin {
  // --- STATE MANAGEMENT ---
  // 0 = Incoming Check (Loud Alarm + Deadman Timer)
  // 1 = Triage (Safe vs Help Buttons)
  // 2 = SOS Active (Beacon Mode: Strobe, Siren, Mesh Broadcast)
  int _state = 0;
  
  // Resources
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _ringtone = AudioPlayer();
  Timer? _failsafeTimer;
  int _countdown = 15; // Seconds before auto-SOS

  // Services (Initialized at bottom of file)
  final MeshService _mesh = MeshService();
  final SmsService _sms = SmsService();
  final SirenService _siren = SirenService();
  final FlashlightService _flash = FlashlightService();

  // Animation
  late AnimationController _strobeController;

  @override
  void initState() {
    super.initState();
    // Red screen strobe animation for SOS mode
    _strobeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 500)
    );
    
    _initSafetyProtocol();
  }

  @override
  void dispose() {
    // CRITICAL: Stop all hardware output when leaving screen
    _shutdownSystem(isExit: true);
    _strobeController.dispose();
    _ringtone.dispose();
    super.dispose();
  }

  // --- INITIALIZATION ---
  void _initSafetyProtocol() async {
    // 1. Audio: Play loud tactical siren
    // Note: Ensure 'assets/siren_alert.mp3' exists in your pubspec
    try {
       await _ringtone.setSource(AssetSource('siren_alert.mp3'));
       await _ringtone.setReleaseMode(ReleaseMode.loop);
       await _ringtone.resume();
    } catch (e) {
      debugPrint("Audio Asset missing, skipping sound: $e");
    }
    
    // 2. Haptics: Violent vibration heartbeat
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0); 
    }

    // 3. TTS: Voice Command
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    _speakPrompts();

    // 4. Deadman Switch: Start countdown
    _startCountdown();
  }

  void _speakPrompts() async {
    while (_state == 0 && mounted) {
      await _tts.speak("Safety Check Active. Are you safe?");
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  void _startCountdown() {
    _failsafeTimer?.cancel();
    _failsafeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          // TIME UP: Assume user is incapacitated
          _triggerSOS("UNRESPONSIVE / TIMEOUT");
        }
      });
    });
  }

  // --- LOGIC ACTIONS ---

  void _userResponded() {
    _failsafeTimer?.cancel();
    _ringtone.stop();
    Vibration.cancel();
    _tts.stop();
    
    setState(() {
      _state = 1; // Move to Decision Phase
      _countdown = 15; // Give 15s to decide, otherwise assume panic/confusion
    });
    
    // Restart timer for decision phase (don't let them freeze here)
    _startCountdown();
  }

  void _markSafe() {
    _shutdownSystem(status: "SAFE");
  }

  void _triggerSOS(String reason) async {
    _failsafeTimer?.cancel();
    
    // Switch to Beacon Mode
    setState(() => _state = 2);
    _strobeController.repeat(reverse: true); // Start flashing screen
    
    // Hardware Activation
    _siren.startSiren();
    _flash.startSosStrobe();

    // Network Broadcast
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final prefs = await SharedPreferences.getInstance();
      String name = prefs.getString('my_name') ?? "Unknown User";
      
      String payload = "CRITICAL | $name | $reason | BAT: ${100}%";
      
      // 1. Mesh Network Broadcast
      _mesh.startEmergencyBroadcast(
        pos.latitude.toString(), 
        pos.longitude.toString(), 
        "SOS", 
        payload
      );

      // 2. SMS Fallback
      List<String> contacts = prefs.getStringList('sos_contacts') ?? [];
      if (contacts.isNotEmpty) {
        _sms.sendBackgroundSms(contacts, pos.latitude.toString(), pos.longitude.toString());
      }
    } catch (e) {
      debugPrint("Location/Network Error: $e");
    }
  }

  void _shutdownSystem({String status = "EXIT", bool isExit = false}) async {
    _failsafeTimer?.cancel();
    _ringtone.stop();
    _tts.stop();
    Vibration.cancel();
    _siren.stopSiren();
    _flash.stopStrobe();

    if (status == "SAFE" && mounted) {
      _mesh.broadcastSafe(); // Tell mesh we are okay
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marked Safe. Systems Standby."), backgroundColor: Colors.green)
      );
    }
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    // Prevent back button
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Tactical Dark Blue
        body: Stack(
          children: [
            // 1. STROBE LAYER (Only active in SOS state)
            if (_state == 2)
              AnimatedBuilder(
                animation: _strobeController,
                builder: (context, child) {
                  return Container(
                    color: Colors.red.withOpacity(_strobeController.value * 0.6),
                  );
                },
              ),

            // 2. CONTENT LAYER
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // TIMER HEADER
                  if (_state < 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.redAccent),
                          const SizedBox(width: 12),
                          Text(
                            "AUTO-SOS IN $_countdown s",
                            style: const TextStyle(
                              color: Colors.redAccent, 
                              fontWeight: FontWeight.w900, 
                              fontSize: 18,
                              fontFamily: "monospace"
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // --- DYNAMIC UI STATES ---
                  
                  // STATE 0: SLIDE TO ANSWER
                  if (_state == 0) _buildIncomingCallUI(),

                  // STATE 1: TRIAGE (SAFE vs HELP)
                  if (_state == 1) _buildTriageUI(),

                  // STATE 2: SOS BEACON
                  if (_state == 2) _buildBeaconUI(),

                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallUI() {
    return Column(
      children: [
        AvatarGlow(
          startDelay: const Duration(milliseconds: 1000),
          glowColor: Colors.cyan,
          glowShape: BoxShape.circle,
          animate: true,
          curve: Curves.fastOutSlowIn,
          child: Material(
            elevation: 8.0,
            shape: const CircleBorder(),
            color: Colors.transparent,
            child: CircleAvatar(
              backgroundColor: Colors.cyan.withOpacity(0.2),
              radius: 60.0,
              child: const Icon(Icons.health_and_safety, size: 50, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          widget.triggerCause.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, letterSpacing: 4),
        ),
        const SizedBox(height: 10),
        const Text(
          "SAFETY CHECK",
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 80),
        
        // Custom Slide to Act (Using Dismissible for clean dependency management)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              _userResponded();
              return false; // Don't remove widget
            },
            background: Container(
              decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(50)),
            ),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white30)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chevron_left, color: Colors.white54),
                  Text("  SLIDE TO RESPOND  ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTriageUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text("WHAT IS YOUR STATUS?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          
          // I AM SAFE BUTTON
          SizedBox(
            width: double.infinity,
            height: 90,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10
              ),
              icon: const Icon(Icons.check_circle, size: 32),
              label: const Text("I AM SAFE\n(Cancel Alarm)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              onPressed: _markSafe,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // I NEED HELP BUTTON
          SizedBox(
            width: double.infinity,
            height: 90,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10
              ),
              icon: const Icon(Icons.sos, size: 32),
              label: const Text("I NEED HELP\n(Broadcast SOS)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              onPressed: () => _triggerSOS("MANUAL REQUEST"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeaconUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 20),
          const Text("SOS BEACON ACTIVE", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Broadcasting Location via Mesh & SMS...", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          const LinearProgressIndicator(color: Colors.red),
          const SizedBox(height: 60),
          
          TextButton(
            onPressed: () => _shutdownSystem(status: "SAFE"),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              side: const BorderSide(color: Colors.white30)
            ),
            child: const Text("FALSE ALARM - CANCEL", style: TextStyle(color: Colors.white, letterSpacing: 1)),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// --- MOCK SERVICES (Placeholders for your actual implementations) ---
// ---------------------------------------------------------------------------

class MeshService {
  void startEmergencyBroadcast(String lat, String long, String type, String payload) {
    debugPrint("[MESH] BROADCASTING SOS: $lat, $long | $payload");
  }
  void broadcastSafe() {
    debugPrint("[MESH] SENDING SAFE STATUS");
  }
}

class SmsService {
  void sendBackgroundSms(List<String> contacts, String lat, String long) {
    debugPrint("[SMS] Sending coords to ${contacts.length} contacts");
  }
}

class SirenService {
  void startSiren() => debugPrint("[HARDWARE] SIREN ON (Max Volume)");
  void stopSiren() => debugPrint("[HARDWARE] SIREN OFF");
}

class FlashlightService {
  void startSosStrobe() => debugPrint("[HARDWARE] FLASHLIGHT STROBE ON");
  void stopStrobe() => debugPrint("[HARDWARE] FLASHLIGHT OFF");
}
