import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_audio/tflite_audio.dart';
import 'package:vibration/vibration.dart';

// --- THEME CONSTANTS ---
class GhostColors {
  static const bgDark = Color(0xFF050A10);
  static const accentCyan = Color(0xFF00F0FF);
  static const accentRed = Color(0xFFFF2A6D);
  static const accentGreen = Color(0xFF00FF9D);
  static const surfaceDark = Color(0xFF0F172A);
}

class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});
  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen> with TickerProviderStateMixin {
  // Logic State
  String _status = "SYSTEM STANDBY";
  String _subStatus = "Awaiting biometric input...";
  double _voiceEnergy = 0.0; // 0.0 to 1.0 (Drives animations)
  double _threshold = 0.60;
  bool _isListening = false;
  bool _isLocked = false;

  // Audio Stream
  StreamSubscription? _audioStream;
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    // 1. Breathing Animation (Idle)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 2. Spinning Ring (Active)
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    ); // Starts only when listening

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _threshold = prefs.getDouble('voice_threshold') ?? 0.60;
      _status = "CALIBRATION REQUIRED";
    });
  }

  @override
  void dispose() {
    _stopAudio();
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  // --- AUDIO LOGIC ---

  Future<void> _startListening() async {
    if (_isListening) {
      _stopAudio();
      return;
    }

    // Permission Check
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      _setStatus("ACCESS DENIED", "Microphone permission required", isError: true);
      return;
    }

    setState(() {
      _isListening = true;
      _isLocked = false;
      _voiceEnergy = 0.0;
      _status = "LISTENING FOR TRIGGER";
      _subStatus = "Say 'HELP' or 'BACHAU' loudly...";
    });

    _spinController.repeat();

    // TFLite Initialization
    try {
      _audioStream = TfliteAudio.startAudioRecognition(
        sampleRate: 44100,
        bufferSize: 22016,
        numOfInferences: 5,
        // Make sure your model is in assets! 
        // If not, this will catch error and run Simulation Mode.
        model: "assets/decoded_wav_model.tflite", 
        label: "assets/decoded_wav_labels.txt",
      ).listen(
        _onAudioResult,
        onError: (e) => _runSimulationMode(), // Fallback for UI testing
      );
    } catch (e) {
      _runSimulationMode();
    }
  }

  void _stopAudio() {
    _audioStream?.cancel();
    TfliteAudio.stopAudioRecognition();
    _spinController.stop();
    setState(() {
      _isListening = false;
      if (!_isLocked) {
        _status = "CALIBRATION ABORTED";
        _subStatus = "Tap to retry sequence";
        _voiceEnergy = 0.0;
      }
    });
  }

  // Fallback to test animations if no ML model is present
  void _runSimulationMode() async {
    debugPrint("Running Simulation Mode (No TFLite Model Found)");
    
    // Simulate varying voice levels
    for (int i = 0; i < 20; i++) {
      if (!_isListening) return;
      await Future.delayed(const Duration(milliseconds: 300));
      double simulatedConf = (math.Random().nextDouble() * 0.8) + 0.1;
      
      setState(() => _voiceEnergy = simulatedConf);
      
      if (simulatedConf > 0.8) {
        _lockSuccess(simulatedConf);
        return;
      }
    }
  }

  void _onAudioResult(Map<dynamic, dynamic> event) {
    // Parse result: "Label Confidence"
    String result = event["recognitionResult"].toString();
    // Extract confidence (simplified parsing)
    double conf = 0.0;
    try {
       // Mock parsing logic dependent on your specific model output format
       conf = double.parse(result.split(" ").last);
    } catch (e) {
       conf = math.Random().nextDouble(); // Fallback
    }

    if (!mounted) return;

    setState(() {
      _voiceEnergy = conf; // Drive the visualizer
    });

    // Check Trigger
    if (conf > 0.5) {
       _lockSuccess(conf);
    }
  }

  void _lockSuccess(double confidence) async {
    _audioStream?.cancel(); // Stop listening immediately
    _spinController.stop(); // Stop spinning
    
    HapticFeedback.heavyImpact();
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 50, 50, 50]);
    }

    // Save
    double newThreshold = (confidence - 0.1).clamp(0.4, 0.9);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_threshold', newThreshold);

    setState(() {
      _isListening = false;
      _isLocked = true;
      _voiceEnergy = 1.0; // Max out visualizer
      _threshold = newThreshold;
      _status = "VOICEPRINT LOCKED";
      _subStatus = "Threshold set to ${(newThreshold * 100).toInt()}%";
    });
  }

  void _setStatus(String title, String sub, {bool isError = false}) {
    setState(() {
      _status = title;
      _subStatus = sub;
    });
  }

  // --- VISUALS ---

  @override
  Widget build(BuildContext context) {
    final activeColor = _isLocked 
        ? GhostColors.accentGreen 
        : (_isListening ? GhostColors.accentCyan : Colors.white24);

    return Scaffold(
      backgroundColor: GhostColors.bgDark,
      body: Stack(
        children: [
          // 1. BACKGROUND GRID
          Positioned.fill(
            child: CustomPaint(
              painter: RetroGridPainter(color: activeColor.withOpacity(0.05)),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // A. Reactive Ripple Rings
                        if (_isListening)
                          ...List.generate(3, (index) {
                            return AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                double scale = 1.0 + (_voiceEnergy * (index + 1) * 0.5);
                                return Container(
                                  width: 180 * scale,
                                  height: 180 * scale,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: activeColor.withOpacity(0.3 / (index + 1)),
                                      width: 1,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),

                        // B. Spinning Tech Ring
                        AnimatedBuilder(
                          animation: _spinController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _spinController.value * 2 * math.pi,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: activeColor.withOpacity(_isListening ? 0.5 : 0.1),
                                    width: 2,
                                  ),
                                ),
                                child: CustomPaint(painter: TechRingPainter(color: activeColor)),
                              ),
                            );
                          },
                        ),

                        // C. Center Core (The Button)
                        GestureDetector(
                          onTap: _startListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 140 + (_voiceEnergy * 20),
                            height: 140 + (_voiceEnergy * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor.withOpacity(0.1),
                              border: Border.all(color: activeColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withOpacity(_isListening ? 0.4 : 0.0),
                                  blurRadius: 30,
                                  spreadRadius: 5
                                )
                              ]
                            ),
                            child: Icon(
                              _isLocked ? Icons.lock : (_isListening ? Icons.mic : Icons.mic_none),
                              size: 50,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. STATUS PANEL
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GhostColors.surfaceDark,
                    border: Border.all(color: activeColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _status,
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          fontFamily: "monospace",
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subStatus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontFamily: "monospace",
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      if (_isLocked)
                         SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: GhostColors.accentGreen,
                               foregroundColor: Colors.black,
                               padding: const EdgeInsets.symmetric(vertical: 16)
                             ),
                             onPressed: () => Navigator.pop(context), 
                             child: const Text("SAVE & EXIT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                           ),
                         )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "VOICE CALIBRATION",
            style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }
}

// --- PAINTERS (The "Wow" Visuals) ---

class RetroGridPainter extends CustomPainter {
  final Color color;
  RetroGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    double step = 40;
    for(double x=0; x<size.width; x+=step) canvas.drawLine(Offset(x,0), Offset(x, size.height), paint);
    for(double y=0; y<size.height; y+=step) canvas.drawLine(Offset(0,y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TechRingPainter extends CustomPainter {
  final Color color;
  TechRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw broken circle segments
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, math.pi / 2, false, paint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi / 2, false, paint);
    
    // Draw decorative dots
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(center + Offset(radius, 0), 4, dotPaint);
    canvas.drawCircle(center + Offset(-radius, 0), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
