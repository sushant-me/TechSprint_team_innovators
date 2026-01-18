import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghostsignal/main.dart'; // Ensure this points to your real dashboard

class DisclosureScreen extends StatefulWidget {
  const DisclosureScreen({super.key});

  @override
  State<DisclosureScreen> createState() => _DisclosureScreenState();
}

class _DisclosureScreenState extends State<DisclosureScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _scanController;
  late AnimationController _pulseController;
  
  // State
  bool _isUnlocked = false;
  double _dragValue = 0.0;
  final double _sliderWidth = 300.0;
  String _headerText = "X_X_X_X"; 
  
  // Data
  final List<Map<String, dynamic>> _items = [
    {
      "icon": Icons.sensors,
      "title": "SENSOR_FUSION",
      "desc": "Access granted to accelerometer & gyroscope for impact detection algorithms."
    },
    {
      "icon": Icons.gps_fixed,
      "title": "GEOSPATIAL_LOCK",
      "desc": " precise location telemetry transmission during active emergency events."
    },
    {
      "icon": Icons.graphic_eq,
      "title": "AUDIO_ANALYSIS",
      "desc": "Background microphone processing for 'HELP' keyword triggers."
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // 1. Scanline Animation
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 2. Pulse Animation for the slider
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 3. Decoding Text Effect
    _decodeTitle();
  }

  void _decodeTitle() async {
    String target = "SYSTEM PROTOCOLS";
    String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#\$%^&*";
    Random r = Random();
    
    for (int i = 0; i < target.length * 2; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() {
        _headerText = List.generate(target.length, (index) {
          if (index < i / 2) return target[index];
          return chars[r.nextInt(chars.length)];
        }).join();
      });
    }
  }

  void _onSlideUpdate(DragUpdateDetails details) {
    if (_isUnlocked) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, _sliderWidth - 60);
    });
  }

  void _onSlideEnd(DragEndDetails details) async {
    if (_isUnlocked) return;
    
    // Threshold to unlock
    if (_dragValue > _sliderWidth - 80) {
      _unlockSystem();
    } else {
      // Snap back
      setState(() => _dragValue = 0.0);
    }
  }

  void _unlockSystem() async {
    setState(() {
      _dragValue = _sliderWidth - 60;
      _isUnlocked = true;
    });
    
    HapticFeedback.heavyImpact();
    
    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms', true);

    // Dramatic pause before navigation
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, _) => const GhostDashboard(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation), child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // 1. GRID BACKGROUND
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.network(
                "https://i.pinimg.com/originals/3d/82/02/3d820235332da75949d0124896230f81.png", // Or local asset
                repeat: ImageRepeat.repeat,
                errorBuilder: (c, e, s) => Container(),
              ),
            ),
          ),

          // 2. SCANLINE OVERLAY
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * _scanController.value,
                left: 0, right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                    ],
                    color: Colors.redAccent,
                  ),
                ),
              );
            },
          ),

          // 3. MAIN CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.shield_moon, color: Colors.redAccent, size: 30),
                      const SizedBox(width: 15),
                      Text(
                        _headerText,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontFamily: "monospace", 
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.redAccent, thickness: 1, height: 40),
                  
                  // Scrollable Cards
                  Expanded(
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => _buildHoloCard(_items[i], i),
                    ),
                  ),
                  
                  // Footer Text
                  Center(
                    child: Text(
                      "INITIALIZING THIS PROTOCOL GRANTS HARDWARE LEVEL ACCESS",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. SLIDE TO UNLOCK
                  _buildTacticalSlider(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoloCard(Map<String, dynamic> item, int index) {
    // Staggered Entrance
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 500 + (index * 200)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - val)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(4), // Sharp tactical corners
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(item['icon'], color: Colors.redAccent),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: "monospace")),
                  const SizedBox(height: 5),
                  Text(item['desc'], style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalSlider() {
    return Center(
      child: Container(
        width: _sliderWidth,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _isUnlocked ? Colors.greenAccent : Colors.white24),
          boxShadow: [
            if (_isUnlocked) BoxShadow(color: Colors.greenAccent, blurRadius: 20)
          ]
        ),
        child: Stack(
          children: [
            // Background Text
            Center(
              child: AnimatedOpacity(
                opacity: _isUnlocked ? 0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Text(
                      "SLIDE TO INITIALIZE >>",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2 + (_pulseController.value * 0.3)),
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Success Text
            if (_isUnlocked)
              const Center(
                child: Text(
                  "ACCESS GRANTED",
                  style: TextStyle(color: Colors.greenAccent, letterSpacing: 2, fontWeight: FontWeight.bold),
                ),
              ),

            // Draggable Handle
            Positioned(
              left: _dragValue,
              top: 0, bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: _onSlideUpdate,
                onHorizontalDragEnd: _onSlideEnd,
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _isUnlocked ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isUnlocked ? Colors.greenAccent : Colors.redAccent,
                        blurRadius: 10
                      )
                    ]
                  ),
                  child: Icon(
                    _isUnlocked ? Icons.check : Icons.chevron_right,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
