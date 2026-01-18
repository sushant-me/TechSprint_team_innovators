import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- MOCK SERVICES (Replace with your real Ghost Signal logic) ---
class MeshService {
  Future<void> checkPermissions() async {}
  void startScanning() {}
  void pingTarget(String id) {}
}

class RescuerScreen extends StatefulWidget {
  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> with TickerProviderStateMixin {
  final MeshService _mesh = MeshService();
  final ScrollController _terminalScroll = ScrollController();
  
  // Animation Controllers
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  
  // State
  final List<String> _logs = [];
  String? _selectedTargetId;
  
  // Mock Data: Detected Mesh Nodes (Victims) relative to Rescuer
  // Angle is in radians (0 is North/Up), Distance 0.0 to 1.0
  final List<Map<String, dynamic>> _targets = [
    {'id': 'V-104', 'angle': 0.5, 'dist': 0.4, 'status': 'CRITICAL', 'hr': 140, 'bat': 12},
    {'id': 'V-209', 'angle': 3.8, 'dist': 0.7, 'status': 'STABLE', 'hr': 85, 'bat': 45},
    {'id': 'V-003', 'angle': 5.2, 'dist': 0.3, 'status': 'UNKNOWN', 'hr': 0, 'bat': 5},
  ];

  @override
  void initState() {
    super.initState();
    
    // 1. Radar Sweep Animation (Infinite Rotation)
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 2. Target Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _initializeSystem();
  }

  void _initializeSystem() async {
    await _mesh.checkPermissions();
    _addLog("SYSTEM_BOOT_COMPLETE");
    _addLog("MESH_NET_LAYER: ACTIVE");
    _addLog("SCANNING_FREQ: 900MHz...");
  }

  void _addLog(String msg) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _logs.add("[${DateTime.now().second}.${DateTime.now().millisecond}] $msg");
    });
    // Auto-scroll terminal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScroll.hasClients) {
        _terminalScroll.animateTo(
          _terminalScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectTarget(String id) {
    if (_selectedTargetId == id) return;
    setState(() => _selectedTargetId = id);
    _addLog("TARGET_LOCKED: $id");
    HapticFeedback.heavyImpact();
  }

  void _pingTarget() {
    if (_selectedTargetId == null) return;
    _mesh.pingTarget(_selectedTargetId!);
    _addLog(">>> SENDING_AUDIO_BEACON >>> $_selectedTargetId");
    HapticFeedback.vibrate();
    
    // Simulate response
    Future.delayed(const Duration(seconds: 2), () {
      _addLog("ACK_RECEIVED: $_selectedTargetId (Signal Strong)");
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    _terminalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme Constants
    final bgDark = const Color(0xFF050F05);
    final hudGreen = const Color(0xFF00FF41);
    final alertRed = const Color(0xFFFF2A2A);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. BACKGROUND GRID
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/grid_pattern.png', // Optional: Replace with a CustomPainter grid if no asset
                repeat: ImageRepeat.repeat,
                errorBuilder: (c, o, s) => Container(), // Fallback
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2. HEADER
                _buildHeader(hudGreen),

                // 3. RADAR DISPLAY (The Core Feature)
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The Sonar Painter
                        AnimatedBuilder(
                          animation: _sweepController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(340, 340),
                              painter: RadarPainter(
                                sweepAngle: _sweepController.value * 2 * math.pi,
                                color: hudGreen,
                              ),
                            );
                          },
                        ),
                        // The Targets (Blips)
                        ..._targets.map((t) => _buildBlip(t, hudGreen, alertRed)),
                        
                        // Center Rescuer Icon
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: hudGreen,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: hudGreen, blurRadius: 10)]
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // 4. TRIAGE / INFO PANEL
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: hudGreen.withOpacity(0.3)),
                      color: Colors.black54,
                    ),
                    child: Column(
                      children: [
                        // Telemetry Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          color: hudGreen.withOpacity(0.1),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("TELEMETRY STREAM", style: TextStyle(color: hudGreen, fontFamily: "monospace", fontSize: 12)),
                              if (_selectedTargetId != null)
                                BlinkingText(text: "LIVE FEED", color: alertRed),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: Row(
                            children: [
                              // A. Terminal Log
                              Expanded(
                                flex: 4,
                                child: ListView.builder(
                                  controller: _terminalScroll,
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _logs.length,
                                  itemBuilder: (c, i) => Text(
                                    _logs[i],
                                    style: TextStyle(color: hudGreen.withOpacity(0.8), fontSize: 10, fontFamily: "monospace"),
                                  ),
                                ),
                              ),
                              
                              // B. Active Target Details
                              if (_selectedTargetId != null)
                                Expanded(
                                  flex: 3,
                                  child: _buildTargetCard(hudGreen, alertRed),
                                )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.radar, color: color),
              const SizedBox(width: 10),
              Text("GHOST_FINDER v3.0", style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: color)),
            child: Text("MESH: ONLINE", style: TextStyle(color: color, fontSize: 10)),
          )
        ],
      ),
    );
  }

  Widget _buildBlip(Map<String, dynamic> target, Color color, Color alert) {
    // Convert Polar (angle, dist) to Cartesian (x, y) for Stack positioning
    // 170 is half the radar size (340)
    final double r = target['dist'] * 170;
    final double theta = target['angle'] - (math.pi / 2); // Rotate so 0 is Up
    final double x = r * math.cos(theta);
    final double y = r * math.sin(theta);

    bool isSelected = _selectedTargetId == target['id'];
    Color blipColor = target['status'] == 'CRITICAL' ? alert : color;

    return Transform.translate(
      offset: Offset(x, y),
      child: GestureDetector(
        onTap: () => _selectTarget(target['id']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isSelected ? 30 : 12,
          height: isSelected ? 30 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
            color: blipColor.withOpacity(isSelected ? 1.0 : 0.6),
            boxShadow: [
              if (isSelected) BoxShadow(color: blipColor, blurRadius: 15, spreadRadius: 2)
            ]
          ),
          child: isSelected ? const Icon(Icons.close, size: 14, color: Colors.black) : null, // Target reticle
        ),
      ),
    );
  }

  Widget _buildTargetCard(Color mainColor, Color alertColor) {
    final target = _targets.firstWhere((t) => t['id'] == _selectedTargetId);
    
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.1),
        border: Border(left: BorderSide(color: mainColor, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ID: ${target['id']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          _statRow("DIST", "${(target['dist'] * 500).toInt()}m", mainColor),
          _statRow("HR", "${target['hr']} bpm", Colors.white),
          _statRow("BAT", "${target['bat']}%", target['bat'] < 20 ? alertColor : mainColor),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: mainColor, padding: EdgeInsets.zero),
              onPressed: _pingTarget,
              child: const Text("PING", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _statRow(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(val, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: "monospace")),
        ],
      ),
    );
  }
}

// --- CUSTOM PAINTERS & UTILS ---

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final Color color;

  RadarPainter({required this.sweepAngle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = color.withOpacity(0.3);

    // 1. Draw Concentric Circles (Distance Markers)
    canvas.drawCircle(center, radius * 0.33, paint);
    canvas.drawCircle(center, radius * 0.66, paint);
    canvas.drawCircle(center, radius, paint);

    // 2. Draw Crosshairs
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);

    // 3. Draw Sweep Gradient
    // We want the sweep to rotate around the center
    final sweepPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - (math.pi / 2), // Adjust start to align with trailing edge
        endAngle: sweepAngle,
        colors: [Colors.transparent, color.withOpacity(0.5)],
        stops: const [0.8, 1.0], // The "beam" width
        transform: GradientRotation(sweepAngle) // This rotates the gradient
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // We draw a full circle with the rotating sweep shader
    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => oldDelegate.sweepAngle != sweepAngle;
}

class BlinkingText extends StatefulWidget {
  final String text;
  final Color color;
  const BlinkingText({super.key, required this.text, required this.color});
  @override
  State<BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    super.initState();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _c, child: Text(widget.text, style: TextStyle(color: widget.color, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}
