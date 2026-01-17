import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avatar_glow/avatar_glow.dart';

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

class _SafetyCheckScreenState extends State<SafetyCheckScreen> {
  // 0 = Incoming Call (Swipe UI)
  // 1 = Active Call (Keypad UI)
  // 2 = SOS Triggered (Red Screen)
  int _callState = 0;

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _ringtone = AudioPlayer();
  Timer? _timeoutTimer;

  final MeshService _mesh = MeshService();
  final SmsService _sms = SmsService();
  final SirenService _siren = SirenService();
  final FlashlightService _flash = FlashlightService();

  @override
  void initState() {
    super.initState();
    _startIncomingCall();
  }

  void _startIncomingCall() async {
    // 1. API Check
    bool confirmed = false;
    if (widget.triggerCause == "Earthquake") {
      confirmed = await EarthquakeApiService().verifyEarthquakeNearby();
    }

    // 2. Ringtone & Vibrate
    await _ringtone.setSource(AssetSource('siren.mp3'));
    await _ringtone.setVolume(1.0); // Loud
    await _ringtone.setReleaseMode(ReleaseMode.loop);
    await _ringtone.resume();
    Vibration.vibrate(pattern: [1000, 1000], repeat: 1);

    // 3. Announcement
    await Future.delayed(const Duration(seconds: 2));
    String text = "Safety Check.";
    if (confirmed) text += " Earthquake confirmed.";
    text += " Swipe green to answer.";

    await _tts.setLanguage("en-US");
    await _tts.setVolume(1.0);
    await _tts.speak(text);

    // 4. Timeout (15s)
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _callState == 0)
        _triggerGlobalSOS("Unconscious / No Answer");
    });
  }

  void _answerCall() async {
    // STOP Ringing
    _timeoutTimer?.cancel();
    await _ringtone.stop();
    Vibration.cancel();

    setState(() => _callState = 1);

    // SPEAK INSTRUCTIONS
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5); // Clear
    await _tts.speak("If you are fine, press 1. If you need help, press 2.");

    // Timeout (10s)
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _triggerGlobalSOS("Silent Call");
    });
  }

  void _declineCall() {
    _shutdown("SAFE");
  }

  void _handleKeypad(String key) {
    if (key == "1") _shutdown("SAFE");
    if (key == "2") _triggerGlobalSOS("User Requested Help");
  }

  void _shutdown(String status) async {
    // KILL ALL NOISE AND LIGHT
    _timeoutTimer?.cancel();
    await _ringtone.stop();
    await _tts.stop();
    Vibration.cancel();
    await _siren.stopSiren();
    _flash.stopStrobe();

    if (status == "SAFE") {
      await _mesh.broadcastSafe();
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Verified Safe. All Alarms Stopped.")));
    }
  }

  Future<void> _triggerGlobalSOS(String reason) async {
    _timeoutTimer?.cancel();
    _ringtone.stop();
    _tts.stop();

    // START EMERGENCY SYSTEMS
    _siren.startSiren();
    _flash.startSosStrobe();

    String lat = "0.0", long = "0.0";
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      lat = pos.latitude.toString();
      long = pos.longitude.toString();
    } catch (e) {
      print(e);
    }

    final prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('my_name') ?? "Unknown";
    String cond = prefs.getString('my_condition') ?? "None";
    List<String> contacts = prefs.getStringList('sos_contacts') ?? [];

    if (contacts.isNotEmpty) _sms.sendBackgroundSms(contacts, lat, long);
    await _mesh.startEmergencyBroadcast(lat, long, name, "$cond | $reason");

    if (mounted) setState(() => _callState = 2);
  }

  @override
  void dispose() {
    _shutdown("EXIT");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SOS UI
    if (_callState == 2) {
      return Scaffold(
        backgroundColor: const Color(0xFFEF4444),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
              Icon(Icons.warning_amber, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text("SOS SENT",
                  style: TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              Text("Emergency Contacts Notified",
                  style: TextStyle(color: Colors.white70))
            ])),
      );
    }

    // MAIN CALL UI
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)])),
        child: Column(
          children: [
            const SizedBox(height: 100),

            // PULSING CALLER ID
            AvatarGlow(
              glowColor:
                  _callState == 0 ? Colors.cyanAccent : Colors.greenAccent,
              endRadius: 100.0,
              duration: const Duration(milliseconds: 2000),
              repeat: true,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24)),
                child:
                    const Icon(Icons.security, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Ghost Signal",
                style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            Text(
                _callState == 0
                    ? "Safety Check Incoming..."
                    : "Voice Verification Active",
                style: const TextStyle(color: Colors.white54)),

            const Spacer(),

            // STATE 0: SLIDE TO ANSWER
            if (_callState == 0) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.horizontal,
                  onDismissed: (dir) {
                    if (dir == DismissDirection.startToEnd)
                      _answerCall();
                    else
                      _declineCall();
                  },
                  background:
                      _swipeBg(Alignment.centerLeft, Colors.green, Icons.call),
                  secondaryBackground: _swipeBg(
                      Alignment.centerRight, Colors.red, Icons.call_end),
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(color: Colors.white12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.chevron_left, color: Colors.white54),
                        Text("  Slide to Answer  ",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                        Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              )
            ],

            // STATE 1: KEYPAD
            if (_callState == 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _optionBtn("1", "I AM FINE", Colors.green,
                        () => _handleKeypad("1")),
                    const SizedBox(height: 20),
                    _optionBtn("2", "I NEED HELP", Colors.red,
                        () => _handleKeypad("2")),
                    const SizedBox(height: 40),
                    FloatingActionButton(
                        backgroundColor: Colors.red,
                        onPressed: _declineCall,
                        child: const Icon(Icons.call_end))
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ]
          ],
        ),
      ),
    );
  }

  Widget _swipeBg(Alignment align, Color color, IconData icon) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(35)),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _optionBtn(String key, String label, Color color, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 25),
        decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color, width: 2)),
        child: Center(
          child: Text("Press $key : $label",
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
