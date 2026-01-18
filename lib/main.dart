import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:avatar_glow/avatar_glow.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

// Services (Assumed existing)
import 'package:ghostsignal/services/audio_detector.dart';
import 'package:ghostsignal/services/motion_detector.dart';
import 'package:ghostsignal/services/beacon_service.dart';
import 'package:ghostsignal/services/notification_service.dart';

// Screens (Assumed existing)
import 'package:ghostsignal/screens/countdown_screen.dart';
import 'package:ghostsignal/screens/contact_screen.dart';
import 'package:ghostsignal/screens/voice_calibration_screen.dart';
import 'package:ghostsignal/screens/disclosure_screen.dart';

// --- THEME CONSTANTS ---
class GhostColors {
  static const bgDark = Color(0xFF0B1121); // Darker Slate
  static const bgLight = Color(0xFF1E293B);
  static const accentCyan = Color(0xFF00F0FF); // Cyberpunk Cyan
  static const accentRed = Color(0xFFFF2A6D);  // Cyberpunk Red
  static const textWhite = Color(0xFFE2E8F0);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientation and overlay style
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await NotificationService.init();
  await initializeService();

  final prefs = await SharedPreferences.getInstance();
  bool accepted = prefs.getBool('has_accepted_terms') ?? false;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ghost Signal',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: GhostColors.bgDark,
      cardColor: GhostColors.bgLight,
      colorScheme: const ColorScheme.dark(
        primary: GhostColors.accentCyan,
        secondary: GhostColors.accentRed,
        surface: GhostColors.bgLight,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: GhostColors.textWhite),
      ),
    ),
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
      initialNotificationTitle: 'GHOST SIGNAL ACTIVE',
      initialNotificationContent: 'Sentinel Defense Systems Online',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
  }
  // Background logic listeners here...
}

class GhostDashboard extends StatefulWidget {
  const GhostDashboard({super.key});
  @override
  State<GhostDashboard> createState() => _GhostDashboardState();
}

class _GhostDashboardState extends State<GhostDashboard> with WidgetsBindingObserver {
  // Services
  late AudioDetector _ears;
  late MotionDetector _motion;
  final BeaconService _beacon = BeaconService();

  // State
  bool _isFullDefense = false;
  List<BeaconSignal> _nearbySignals = [];
  Position? _myPos;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _motion.stopMonitoring(); // Ensure we stop sensors
    _beacon.stopScanning();   // Ensure we stop scanners
    super.dispose();
  }

  void _initSystem() async {
    // Initialize Sensors
    _ears = AudioDetector(onSosDetected: () => _triggerEmergency("Voice Command"));
    
    _motion = MotionDetector(onCriticalEvent: (cause) {
      if (!_isFullDefense) _activateFullDefense();
      _triggerEmergency(cause);
    });
    
    // Start base monitoring
    _motion.startMonitoring();
    
    // Position Stream
    if (await Permission.location.request().isGranted) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((pos) => setState(() => _myPos = pos));
    }

    _startBeaconScanning();
  }

  void _startBeaconScanning() async {
    if (await _checkPermissions()) {
      _beacon.startScanning((signals) {
        if (!mounted) return;
        setState(() => _nearbySignals = signals);
        if (signals.isNotEmpty) {
          Vibration.vibrate(duration: 50, amplitude: 128); // Subtle haptic tick
        }
      });
    }
  }

  void _activateFullDefense() async {
    if (await _checkPermissions()) {
      _ears.startListening();
      setState(() => _isFullDefense = true);
      NotificationService.showCriticalAlert("DEFENSE MODE", "Microphone Active. High Sensitivity.");
      Vibration.vibrate(pattern: [0, 100, 50, 100]); // Double buzz confirmation
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
    Vibration.vibrate(duration: 1000);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CountdownScreen(triggerCause: cause))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF000000)],
          ),
        ),
        child: Stack(
          children: [
             // Background Grid/Effect could go here
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 1. HUD Section
                  _SentinelHUD(
                    isArmed: _isFullDefense, 
                    onTap: _activateFullDefense
                  ),
                  
                  const SizedBox(height: 40),

                  // 2. Beacon List Section
                  Expanded(
                    child: _BeaconListPanel(
                      signals: _nearbySignals, 
                      myPos: _myPos
                    ),
                  ),

                  // 3. Action Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: _HoldToPanicButton(
                      onTrigger: () => _triggerEmergency("Manual Panic")
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.waves, color: GhostColors.accentCyan.withOpacity(0.8), size: 20),
          const SizedBox(width: 8),
          const Text("GHOST SIGNAL", 
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.2)),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.shield_outlined, color: Colors.white70),
        onPressed: () => {/* Profile logic */}, // Placeholder
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.graphic_eq, color: Colors.white70),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoiceCalibrationScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.people_outline, color: Colors.white70),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ContactScreen())),
        )
      ],
    );
  }
}

// --- WIDGETS ---

class _SentinelHUD extends StatelessWidget {
  final bool isArmed;
  final VoidCallback onTap;

  const _SentinelHUD({required this.isArmed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AvatarGlow(
            animate: isArmed,
            glowColor: isArmed ? GhostColors.accentCyan : Colors.blueGrey,
            endRadius: 100.0,
            duration: const Duration(milliseconds: 2000),
            repeat: true,
            showTwoGlows: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isArmed ? GhostColors.accentCyan.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: isArmed ? GhostColors.accentCyan : Colors.white24,
                  width: 2
                ),
                boxShadow: [
                  if (isArmed) BoxShadow(color: GhostColors.accentCyan.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)
                ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isArmed ? Icons.security : Icons.radar,
                    size: 50,
                    color: isArmed ? GhostColors.textWhite : Colors.white38
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isArmed ? "ARMED" : "PASSIVE",
                    style: TextStyle(
                      color: isArmed ? GhostColors.accentCyan : Colors.white38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5
                    ),
                  )
                ],
              ),
            ),
          ),
          Text(
            isArmed ? "LISTENING FOR DISTRESS" : "TAP TO ARM SENSORS",
            style: TextStyle(color: isArmed ? GhostColors.accentCyan : Colors.white30, fontSize: 12, letterSpacing: 1),
          )
        ],
      ),
    );
  }
}

class _BeaconListPanel extends StatelessWidget {
  final List<BeaconSignal> signals;
  final Position? myPos;

  const _BeaconListPanel({required this.signals, this.myPos});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_tethering, color: GhostColors.accentRed, size: 20),
                    const SizedBox(width: 10),
                    const Text("DETECTED SIGNALS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                      child: Text("${signals.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              Expanded(
                child: signals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_find, size: 50, color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 10),
                            const Text("No Distress Beacons Nearby", style: TextStyle(color: Colors.white24)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: signals.length,
                        itemBuilder: (ctx, i) {
                          final signal = signals[i];
                          final dist = _calculateDistance(signal);
                          return _BeaconCard(signal: signal, distance: dist);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateDistance(BeaconSignal v) {
    if (myPos != null && double.tryParse(v.lat) != 0) {
      final d = Geolocator.distanceBetween(
        myPos!.latitude, myPos!.longitude, 
        double.tryParse(v.lat) ?? 0, double.tryParse(v.long) ?? 0
      );
      return "${d.toStringAsFixed(0)}m";
    }
    return "? m";
  }
}

class _BeaconCard extends StatelessWidget {
  final BeaconSignal signal;
  final String distance;

  const _BeaconCard({required this.signal, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GhostColors.accentRed.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: GhostColors.accentRed.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: GhostColors.accentRed),
        ),
        title: Text(signal.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Text(signal.condition, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(distance, style: const TextStyle(color: GhostColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.near_me, color: Colors.blue),
          onPressed: () => launchUrl(
            Uri.parse("http://maps.google.com/?q=${signal.lat},${signal.long}"),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    );
  }
}

class _HoldToPanicButton extends StatefulWidget {
  final VoidCallback onTrigger;
  const _HoldToPanicButton({required this.onTrigger});

  @override
  State<_HoldToPanicButton> createState() => _HoldToPanicButtonState();
}

class _HoldToPanicButtonState extends State<_HoldToPanicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onTrigger();
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _controller.forward();
        Vibration.vibrate(pattern: [0, 50, 50, 50]); // Initial feedback
      },
      onLongPressEnd: (_) {
        if (_controller.isAnimating) _controller.reset();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              color: GhostColors.accentRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GhostColors.accentRed.withOpacity(0.5)),
            ),
            child: Stack(
              children: [
                // Progress Fill
                FractionallySizedBox(
                  widthFactor: _controller.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: GhostColors.accentRed,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: GhostColors.accentRed.withOpacity(0.5), blurRadius: 20)]
                    ),
                  ),
                ),
                // Text/Icon
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        _controller.isAnimating ? "HOLD TO TRIGGER..." : "HOLD FOR SOS",
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 18, 
                          letterSpacing: 1.5
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
