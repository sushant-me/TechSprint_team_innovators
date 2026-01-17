import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';
import 'package:ghost_signal/services/mesh_service.dart'; // Import Mesh Service

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  int _timeLeft = 3;
  double _percent = 1.0;
  Timer? _timer;
  bool _isCritical = false; // State when timer hits 0

  // Create an instance of our Mesh Service
  final MeshService _meshService = MeshService();

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  void startCountdown() {
    // 1. Start Aggressive Vibration (Heartbeat pattern)
    // pattern: [wait, vibrate, wait, vibrate...]
    Vibration.vibrate(
        pattern: [500, 1000, 500, 1000, 500, 1000],
        intensities: [128, 255, 128, 255, 128, 255]);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return; // Safety check

      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          _percent = _timeLeft / 3; // Calculate percentage for circle
        } else {
          // 2. TIME IS UP -> TRIGGER SOS
          _isCritical = true;
          _timer?.cancel();
          triggerSOS();
        }
      });
    });
  }

  Future<void> triggerSOS() async {
    // STOP Vibration loop and start CONTINUOUS SOS Vibration
    Vibration.cancel();
    Vibration.vibrate(duration: 10000); // Vibrate for 10 seconds straight

    // FLASH LIGHT LOGIC (Uncomment on Real Device)
    /*
    try {
      await TorchLight.enableTorch(); 
      // Add strobe logic here later
    } catch (e) {
      // Handle error
    }
    */

    // --- START OFFLINE MESH BROADCAST ---
    print("GHOST SIGNAL: INITIALIZING MESH NETWORK...");

    // 1. Ensure we have permission to use Bluetooth/Location
    await _meshService.checkPermissions();

    // 2. Start Broadcasting "SOS" to nearby phones
    await _meshService.startBroadcastingSOS();

    print("GHOST SIGNAL BROADCASTING: SOS PACKETS ARE FLYING!");

    // TODO: Send SMS as Backup (Next Phase)
  }

  void cancelSOS() {
    _timer?.cancel();
    Vibration.cancel();
    // Stop broadcasting if we cancel (Optional, but good practice)
    // Nearby().stopAdvertising();
    Navigator.pop(context); // Go back to Home Screen
  }

  @override
  void dispose() {
    _timer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Changes color based on state: Red (Panic) -> Black (Active Mode)
      backgroundColor: _isCritical ? Colors.black : const Color(0xFFB71C1C),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TOP TEXT
            Text(
              _isCritical ? "GHOST SIGNAL SENT" : "IMPACT DETECTED",
              style: GoogleFonts.bebasNeue(
                fontSize: 40,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _isCritical
                  ? "Rescuers are being notified via Mesh."
                  : "Sending SOS in...",
              style: GoogleFonts.lato(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 50),

            // THE COUNTDOWN CIRCLE
            if (!_isCritical)
              CircularPercentIndicator(
                radius: 120.0,
                lineWidth: 15.0,
                percent: _percent,
                center: Text(
                  "$_timeLeft",
                  style: GoogleFonts.bebasNeue(
                    fontSize: 100,
                    color: Colors.white,
                  ),
                ),
                progressColor: Colors.white,
                backgroundColor: Colors.white24,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animateFromLastPercent: true,
                animationDuration: 1000,
              ),

            // THE SIGNAL ICON (Appears after countdown)
            if (_isCritical)
              const Icon(
                Icons.wifi_tethering_error_rounded, // The "Signal" Icon
                size: 200,
                color: Colors.redAccent,
              ),

            const SizedBox(height: 60),

            // CANCEL BUTTON
            if (!_isCritical)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: cancelSOS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "I AM SAFE (CANCEL)",
                      style: GoogleFonts.bebasNeue(
                        fontSize: 24,
                        color: const Color(0xFFB71C1C),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

            // POST-TRIGGER STATUS TEXT
            if (_isCritical)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Beacon Active.\nBattery Optimization: ON\nMesh Network: BROADCASTING",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceCodePro(
                    // Hacker style font
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
