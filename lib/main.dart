import 'package:flutter/material.dart';
import 'package:ghost_signal/screens/countdown_screen.dart';
import 'package:ghost_signal/services/audio_detector.dart';
import 'package:ghost_signal/services/motion_detector.dart'; // Import Motion

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AudioDetector _audioDetector;
  late MotionDetector _motionDetector;

  @override
  void initState() {
    super.initState();

    // 1. Initialize EARS
    _audioDetector = AudioDetector(onSosDetected: () {
      _launchPanicMode("VOICE TRIGGER");
    });
    _audioDetector.startListening();

    // 2. Initialize GRAVITY
    _motionDetector = MotionDetector(onFallDetected: () {
      _launchPanicMode("FALL DETECTED");
    });
    _motionDetector.startMonitoring();
  }

  // Unified Trigger Function
  void _launchPanicMode(String reason) {
    print("CRITICAL: LAUNCHING SOS DUE TO $reason");

    // Stop sensors temporarily to prevent double-triggering
    _audioDetector.stopListening();
    _motionDetector.stopMonitoring();

    navigatorKey.currentState
        ?.push(
      MaterialPageRoute(builder: (context) => const CountdownScreen()),
    )
        .then((_) {
      // Restart sensors when user returns from Panic Screen (if they cancelled)
      _audioDetector.startListening();
      _motionDetector.startMonitoring();
    });
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Ghost Signal',
      theme: ThemeData.dark(),
      home: const SafeScreen(),
    );
  }
}

class SafeScreen extends StatelessWidget {
  const SafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Pulse Animation (Optional visual flair)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Visual for Ears
                Icon(Icons.mic,
                    size: 60, color: Colors.blueAccent.withOpacity(0.7)),
                const SizedBox(height: 20),

                // Visual for Gravity
                Icon(Icons.monitor_heart,
                    size: 60, color: Colors.redAccent.withOpacity(0.7)),

                const SizedBox(height: 40),
                const Text(
                  "GHOST SIGNAL ACTIVE",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
                const SizedBox(height: 10),
                Text(
                  "• Listening for 'BACHAAAU'\n• Monitoring G-Force for Falls",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), height: 1.5),
                ),
              ],
            ),
          ),

          // Debug Button (In case sensors are tricky to trigger in demo)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () {
                  // Simulate a trigger for testing UI
                  (context as Element)
                      .findAncestorStateOfType<_MyAppState>()
                      ?._launchPanicMode("MANUAL TEST");
                },
                child: const Text("TEST TRIGGER UI",
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
