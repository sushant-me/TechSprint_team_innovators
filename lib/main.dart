import 'dart:async';
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: unused_import
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

// Services
import 'package:ghostsignal/services/audio_detector.dart';
import 'package:ghostsignal/services/motion_detector.dart';
import 'package:ghostsignal/services/beacon_service.dart'; // NEW SERVICE
import 'package:ghostsignal/services/notification_service.dart';

// Screens
import 'package:ghostsignal/screens/countdown_screen.dart';
import 'package:ghostsignal/screens/contact_screen.dart';
import 'package:ghostsignal/screens/voice_calibration_screen.dart';
import 'package:ghostsignal/screens/disclosure_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await initializeService();

  final prefs = await SharedPreferences.getInstance();
  bool accepted = prefs.getBool('has_accepted_terms') ?? false;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ghost Signal',
    theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFFF43F5E),
        )),
    home: accepted ? const GhostDashboard() : const DisclosureScreen(),
  ));
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      initialNotificationTitle: 'Ghost Signal Active',
      initialNotificationContent: 'Sentinel Mode Active',
    ),
    iosConfiguration: IosConfiguration(),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((event) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((event) => service.setAsBackgroundService());
  }
}

class GhostDashboard extends StatefulWidget {
  const GhostDashboard({super.key});
  @override
  State<GhostDashboard> createState() => _GhostDashboardState();
}

class _GhostDashboardState extends State<GhostDashboard>
    with WidgetsBindingObserver {
  late AudioDetector _ears;
  late MotionDetector _motion;
  final BeaconService _beacon = BeaconService();

  bool _isFullDefense = false;
  List<BeaconSignal> _nearbySignals = [];
  Position? _myPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _setupSensors();
    Geolocator.getPositionStream()
        .listen((pos) => setState(() => _myPos = pos));
  }

  void _setupSensors() async {
    // 1. Audio (Mic) -> Privacy Mode (Starts OFF)
    _ears =
        AudioDetector(onSosDetected: () => _triggerEmergency("Voice Command"));

    // 2. Motion (Seismic) -> Sentinel Mode (Starts ON)
    _motion = MotionDetector(onCriticalEvent: (cause) {
      if (!_isFullDefense) _activateFullDefense();
      _triggerEmergency(cause);
    });
    _motion.startMonitoring();

    // 3. Beacon Scanner (Starts ON)
    if (await _checkPermissions()) {
      _beacon.startScanning((signals) {
        if (mounted) setState(() => _nearbySignals = signals);
        if (signals.isNotEmpty) {
          Vibration.vibrate(duration: 500); // One ping only
        }
      });
    }
  }

  void _activateFullDefense() async {
    if (await _checkPermissions()) {
      _ears.startListening();
      setState(() => _isFullDefense = true);
      NotificationService.showCriticalAlert("FULL DEFENSE", "Mic Listening...");
    }
  }

  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.microphone,
      Permission.sms,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.notification,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  void _triggerEmergency(String cause) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CountdownScreen(triggerCause: cause)));
  }

  void _showProfileDialog() {/* Profile Dialog Logic (Keep existing) */}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("GHOST SIGNAL",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.person, color: Colors.cyanAccent),
            onPressed: _showProfileDialog),
        actions: [
          IconButton(
              icon: const Icon(Icons.mic, color: Colors.white54),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const VoiceCalibrationScreen()))),
          IconButton(
              icon: const Icon(Icons.contacts, color: Colors.white54),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const ContactScreen())))
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF020617)])),
        child: Column(
          children: [
            const SizedBox(height: 100),

            // SENTINEL HUD
            GestureDetector(
              onTap: _activateFullDefense,
              child: AvatarGlow(
                animate: _isFullDefense,
                glowColor: _isFullDefense ? Colors.cyanAccent : Colors.blueGrey,
                endRadius: 110.0,
                duration: const Duration(milliseconds: 2000),
                repeat: true,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: _isFullDefense
                              ? [
                                  Colors.cyan.withOpacity(0.2),
                                  Colors.blue.withOpacity(0.1)
                                ]
                              : [
                                  Colors.grey.withOpacity(0.2),
                                  Colors.black.withOpacity(0.1)
                                ]),
                      border: Border.all(
                          color: _isFullDefense
                              ? Colors.cyanAccent
                              : Colors.white12,
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: _isFullDefense
                                ? Colors.cyan.withOpacity(0.3)
                                : Colors.transparent,
                            blurRadius: 20)
                      ]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isFullDefense ? Icons.shield_moon : Icons.sensors,
                          size: 50,
                          color:
                              _isFullDefense ? Colors.white : Colors.white54),
                      const SizedBox(height: 10),
                      Text(_isFullDefense ? "ARMED" : "SENTINEL",
                          style: TextStyle(
                              color: _isFullDefense
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5))
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // BEACON LIST
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30))),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        const Icon(Icons.radar, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        const Text("DISTRESS SIGNALS",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    Expanded(
                      child: _nearbySignals.isEmpty
                          ? Center(
                              child: Text("Scanning for SOS Beacons...",
                                  style: TextStyle(color: Colors.white24)))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _nearbySignals.length,
                              itemBuilder: (ctx, i) {
                                final v = _nearbySignals[i];
                                double dist = 0;
                                if (_myPos != null &&
                                    double.tryParse(v.lat) != 0) {
                                  dist = Geolocator.distanceBetween(
                                      _myPos!.latitude,
                                      _myPos!.longitude,
                                      double.tryParse(v.lat) ?? 0,
                                      double.tryParse(v.long) ?? 0);
                                }
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: Colors.redAccent
                                              .withOpacity(0.3))),
                                  child: ListTile(
                                    leading: const Icon(Icons.warning,
                                        color: Colors.redAccent),
                                    title: Text(v.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        "${v.condition} • ${dist.toStringAsFixed(0)}m",
                                        style: const TextStyle(
                                            color: Colors.white54)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.map,
                                          color: Colors.blue),
                                      onPressed: () => launchUrl(
                                          Uri.parse(
                                              "http://googleusercontent.com/maps.google.com/maps?q=${v.lat},${v.long}"),
                                          mode: LaunchMode.externalApplication),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // SOS BUTTON
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  icon: const Icon(Icons.touch_app, size: 30),
                  label: const Text("TRIGGER SOS",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  onPressed: () => _triggerEmergency("Manual Panic"),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
