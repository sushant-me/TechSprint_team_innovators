import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avatar_glow/avatar_glow.dart';

// Services
import 'package:ghostsignal/services/earthquake_api_service.dart';
import 'package:ghostsignal/services/mesh_service.dart';
import 'package:ghostsignal/services/siren_service.dart';
import 'package:ghostsignal/services/sms_service.dart';
import 'package:ghostsignal/services/flashlight_service.dart';

class SafetyCheckScreen extends StatefulWidget {
  final String triggerCause;
  const SafetyCheckScreen({super.key, required this.triggerCause});

  @override
  State<SafetyCheckScreen> createState() => _SafetyCheckScreenState();
}

class _SafetyCheckScreenState extends State<SafetyCheckScreen> with TickerProviderStateMixin {
  // 0 = Incoming Check (Slide to Answer)
  // 1 = Triage (Safe vs Help)
  // 2 = SOS Active (Beacon Mode)
  int _state = 0;
  
  // Resources
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _ringtone = AudioPlayer();
  Timer? _failsafeTimer;
  int _countdown = 15; // Seconds before auto-SOS

  // Services
  final MeshService _mesh = MeshService();
  final SmsService _sms = SmsService();
  final SirenService _siren = SirenService();
  final FlashlightService _flash = FlashlightService();

  // Animation
  late AnimationController _strobeController;

  @override
  void initState() {
    super.initState();
    _strobeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _initSafetyProtocol();
  }

  @override
  void dispose() {
    _shutdownSystem(isExit: true);
    _strobeController.dispose();
    super.dispose();
  }

  void _initSafetyProtocol() async {
    // 1. Validate Trigger (Optional API check)
    if (widget.triggerCause == "Earthquake") {
      await EarthquakeApiService().verifyEarthquakeNearby();
    }

    // 2. Start Audio/Haptic Loop
    _ringtone.setSource(AssetSource('siren_alert.mp3'));
    _ringtone.setReleaseMode(ReleaseMode.loop);
    _ringtone.resume();
    
    Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0); // Heartbeat pattern

    // 3. Voice Command
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    _tts.speak("Safety Check Active. Are you safe?");

    // 4. Start Deadman Switch (Countdown)
    _startCountdown();
  }

  void _startCountdown() {
    _failsafeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _triggerSOS("Unresponsive / Time Out");
        }
      });
    });
  }

  // --- ACTIONS ---

  void _userResponded() {
    _failsafeTimer?.cancel();
    _ringtone.stop();
    Vibration.cancel();
    _tts.stop();
    setState(() {
      _state = 1; // Move to Decision Phase
      _countdown = 10; // Give them 10s to decide, else assume panic
    });
    // Restart timer for decision phase
    _startCountdown();
  }

  void _markSafe() async {
    _shutdownSystem(status: "SAFE");
  }

  void _triggerSOS(String reason) async {
    _failsafeTimer?.cancel();
    
    // Switch to Beacon Mode
    setState(() => _state = 2);
    _strobeController.repeat(reverse: true);
    
    // Hardware Activation
    _siren.startSiren();
    _flash.startSosStrobe();

    // Network Broadcast
    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final prefs = await SharedPreferences.getInstance();
    
    String payload = "CRITICAL | ${prefs.getString('my_name')} | $reason";
    
    _mesh.startEmergencyBroadcast(
      pos.latitude.toString(), 
      pos.longitude.toString(), 
      "SOS", 
      payload
    );

    List<String> contacts = prefs.getStringList('sos_contacts') ?? [];
    if (contacts.isNotEmpty) {
      _sms.sendBackgroundSms(contacts, pos.latitude.toString(), pos.longitude.toString());
    }
  }

  void _shutdownSystem({String status = "EXIT", bool isExit = false}) async {
    _failsafeTimer?.cancel();
    await _ringtone.stop();
    await _tts.stop();
    Vibration.cancel();
    _siren.stopSiren();
    _flash.stopStrobe();

    if (status == "SAFE" && mounted) {
      _mesh.broadcastSafe();
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marked Safe. Systems Standby."), backgroundColor: Colors.green)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Disable back button during check
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            // Background Alarm Effect (Only in State 2)
            if (_state == 2)
              AnimatedBuilder(
                animation: _strobeController,
                builder: (context, child) {
                  return Container(
                    color: Colors.red.withOpacity(_strobeController.value * 0.5),
                  );
                },
              ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // HEADER: TIMER
                  if (_state < 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, color: Colors.white70),
                          const SizedBox(width: 10),
                          Text(
                            "AUTO-SOS IN $_countdown s",
                            style: const TextStyle(
                              color: Colors.redAccent, 
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // --- UI STATES ---
                  
                  // STATE 0: SLIDE TO ANSWER
                  if (_state == 0) _buildIncomingCallUI(),

                  // STATE 1: DECISION (SAFE vs HELP)
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
          glowColor: Colors.cyanAccent,
          endRadius: 120.0,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyan.withOpacity(0.2),
              border: Border.all(color: Colors.cyanAccent, width: 2)
            ),
            child: const Icon(Icons.health_and_safety, size: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          widget.triggerCause.toUpperCase(),
          style: const TextStyle(color: Colors.redAccent, fontSize: 20, letterSpacing: 5, fontWeight: FontWeight.bold),
        ),
        const Text(
          "SAFETY CHECK DETECTED",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              _userResponded();
              return false; // Don't dismiss the widget, just change state
            },
            background: Container(
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(50)),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 30),
              child: const Icon(Icons.check, color: Colors.white),
            ),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white30)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chevron_left, color: Colors.white54),
                  Text("  SLIDE TO RESPOND  ", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text("WHAT IS YOUR STATUS?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          
          // I AM SAFE
          SizedBox(
            width: double.infinity,
            height: 100,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              icon: const Icon(Icons.check_circle, size: 40),
              label: const Text("I AM SAFE\n(Cancel Alarm)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              onPressed: _markSafe,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // I NEED HELP
          SizedBox(
            width: double.infinity,
            height: 100,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              icon: const Icon(Icons.sos, size: 40),
              label: const Text("I NEED HELP\n(Broadcast SOS)", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              onPressed: () => _triggerSOS("Manual Request"),
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
          const Icon(Icons.warning, size: 100, color: Colors.white),
          const SizedBox(height: 20),
          const Text("SOS BEACON ACTIVE", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Broadcasting Location via Mesh & SMS...", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 50),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)
            ),
            onPressed: () => _shutdownSystem(status: "SAFE"),
            child: const Text("FALSE ALARM - CANCEL", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
