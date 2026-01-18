import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // Changed to Circular
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_audio/tflite_audio.dart';
import 'package:vibration/vibration.dart';

// --- THEME CONSTANTS (Matching previous dashboard) ---
class GhostColors {
  static const bgDark = Color(0xFF0B1121);
  static const accentCyan = Color(0xFF00F0FF);
  static const accentRed = Color(0xFFFF2A6D);
  static const accentGreen = Color(0xFF00FF9D);
  static const textWhite = Color(0xFFE2E8F0);
}

class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});
  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen> with SingleTickerProviderStateMixin {
  // State Variables
  String _status = "INITIALIZING SYSTEM";
  String _instruction = "Tap MIC to start calibration";
  double _currentConfidence = 0.0;
  double _calibratedThreshold = 0.60;
  bool _isListening = false;
  bool _isSuccess = false;

  // Stream Management
  StreamSubscription? _audioStream;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);
    _loadPreviousSettings();
  }

  Future<void> _loadPreviousSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calibratedThreshold = prefs.getDouble('voice_threshold') ?? 0.60;
      _status = "CURRENT THRESHOLD: ${(_calibratedThreshold * 100).toInt()}%";
    });
  }

  @override
  void dispose() {
    _forceStop();
    _pulseController.dispose();
    super.dispose();
  }

  void _forceStop() {
    _audioStream?.cancel();
    TfliteAudio.stopAudioRecognition();
  }

  Future<void> _startCalibration() async {
    if (_isListening) {
      _forceStop();
      setState(() {
        _isListening = false;
        _instruction = "Calibration Aborted";
      });
      return;
    }

    if (!await Permission.microphone.request().isGranted) {
      setState(() => _instruction = "Microphone Permission Denied");
      return;
    }

    setState(() {
      _isListening = true;
      _isSuccess = false;
      _status = "LISTENING...";
      _instruction = "Say 'HELP' or 'BACHAU' clearly";
      _currentConfidence = 0.0;
    });

    // Safety delay to let UI settle
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      _audioStream = TfliteAudio.startAudioRecognition(
        sampleRate: 44100,
        bufferSize: 22016,
        numOfInferences: 5,
      ).listen((event) {
        _processAudioEvent(event);
      }, onError: (e) {
        _handleError(e.toString());
      }, onDone: () {
        // Stream closed naturally (usually via timeout or manual stop)
        if (!_isSuccess) {
           setState(() => _isListening = false);
        }
      });
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _processAudioEvent(Map<dynamic, dynamic> event) {
    // Robust parsing
    String rawResult = event["recognitionResult"]?.toString().toLowerCase() ?? "";
    // Assuming format "label confidence" or just raw string handling
    // We try to extract confidence if available, otherwise default to 0
    double conf = 0.0;
    
    // TFLite Audio usually returns "label 0.95"
    List<String> parts = rawResult.split(" ");
    if (parts.isNotEmpty) {
       double? parsedConf = double.tryParse(parts.last);
       if (parsedConf != null) conf = parsedConf;
    }

    if (!mounted) return;

    setState(() {
      _currentConfidence = conf;
      
      // Visual feedback logic
      if ((rawResult.contains("help") || rawResult.contains("bachau")) && conf > 0.4) {
        _lockInCalibration(conf);
      } else {
        _status = "Scanning... ${(conf * 100).toInt()}%";
      }
    });
  }

  void _lockInCalibration(double confidence) async {
    _forceStop();
    Vibration.vibrate(pattern: [0, 50, 50, 50]); // Success haptics
    
    // Set threshold slightly below detected confidence for reliability
    double newThreshold = (confidence - 0.10).clamp(0.4, 0.9);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_threshold', newThreshold);

    setState(() {
      _isListening = false;
      _isSuccess = true;
      _calibratedThreshold = newThreshold;
      _currentConfidence = 1.0; // Fill the bar for visual success
      _status = "LOCKED: ${(confidence * 100).toInt()}%";
      _instruction = "Threshold set to ${(newThreshold * 100).toInt()}%.\nSystem Saved.";
    });
  }

  void _handleError(String error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _status = "ERROR";
      _instruction = "Init Failed. Try Restarting App.";
    });
    debugPrint("Audio Error: $error");
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color based on state
    Color currentStateColor = _isSuccess 
        ? GhostColors.accentGreen 
        : (_isListening ? GhostColors.accentCyan : Colors.white38);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: GhostColors.bgDark,
      appBar: AppBar(
        title: const Text("VOICE MODULE", style: TextStyle(letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GhostColors.bgDark, Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. VISUALIZER
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 200 * (_isListening ? _pulseController.value : 1.0),
                        height: 200 * (_isListening ? _pulseController.value : 1.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentStateColor.withOpacity(0.1),
                        ),
                      );
                    },
                  ),
                  // Progress Ring
                  CircularPercentIndicator(
                    radius: 90.0,
                    lineWidth: 8.0,
                    percent: _currentConfidence.clamp(0.0, 1.0),
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: Colors.white10,
                    progressColor: currentStateColor,
                    animation: true,
                    animateFromLastPercent: true,
                    animationDuration: 100,
                  ),
                  // Center Icon
                  GestureDetector(
                    onTap: _startCalibration,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: currentStateColor.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(color: currentStateColor.withOpacity(0.2), blurRadius: 20)
                        ]
                      ),
                      child: Icon(
                        _isSuccess ? Icons.check : (_isListening ? Icons.mic : Icons.mic_none),
                        size: 60,
                        color: currentStateColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),

              // 2. TEXT STATUS
              Text(
                _status,
                style: TextStyle(
                  color: currentStateColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2
                ),
              ),
              
              const SizedBox(height: 10),

              Text(
                _instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 50),

              // 3. ACTION BUTTONS
              if (_isSuccess)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GhostColors.accentGreen.withOpacity(0.2),
                        side: const BorderSide(color: GhostColors.accentGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: () => Navigator.pop(context), 
                      child: const Text("CONFIRM & EXIT", style: TextStyle(color: Colors.white, letterSpacing: 1.5)),
                    ),
                  ),
                )
              else if (_isListening)
                TextButton(
                  onPressed: _startCalibration, // Acts as cancel
                  child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent)),
                )
            ],
          ),
        ),
      ),
    );
  }
}
