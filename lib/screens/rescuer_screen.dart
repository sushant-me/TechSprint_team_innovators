import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- MODELS ---
class TargetNode {
  final String id;
  final double angle; // Radians
  final double distance; // 0.0 to 1.0
  final String status;
  final int heartRate;
  final int battery;

  TargetNode({
    required this.id,
    required this.angle,
    required this.distance,
    required this.status,
    required this.heartRate,
    required this.battery,
  });
}

// --- MAIN SCREEN ---
class RescuerScreen extends StatefulWidget {
  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> with TickerProviderStateMixin {
  late AnimationController _sweepController;
  final ScrollController _terminalScroll = ScrollController();
  final List<String> _logs = [];
  String? _selectedTargetId;

  final List<TargetNode> _targets = [
    TargetNode(id: 'V-104', angle: 0.5, distance: 0.4, status: 'CRITICAL', heartRate: 140, battery: 12),
    TargetNode(id: 'V-209', angle: 3.8, distance: 0.7, status: 'STABLE', heartRate: 85, battery: 45),
    TargetNode(id: 'V-003', angle: 5.2, distance: 0.3, status: 'UNKNOWN', heartRate: 0, battery: 5),
  ];

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    
    _addLog("INITIATING GHOST_FINDER PROTOCOL...");
    _addLog("MESH_NET_LAYER: CONNECTED");
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add("[${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}] $msg");
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_terminalScroll.hasClients) {
        _terminalScroll.animateTo(_terminalScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _terminalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color hudGreen = Color(0xFF00FF41);
    const Color bgDark = Color(0xFF020502);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Background Grid Component
          Positioned.fill(child: CustomPaint(painter: GridPainter())),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(hudGreen),
                
                // 2. Radar Section
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.9;
                    return Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar circles and sweeping beam
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _sweepController,
                              builder: (context, _) => CustomPaint(
                                size: Size(size, size),
                                painter: RadarPainter(_sweepController.value, hudGreen),
                              ),
                            ),
                          ),
                          // Target Blips
                          ..._targets.map((t) => _buildTargetBlip(t, size / 2, hudGreen)),
                        ],
                      ),
                    );
                  }),
                ),

                // 3. Bottom Terminal & Info
                _buildBottomPanel(hudGreen),
              ],
            ),
          ),
          
          // 4. CRT Scanline Overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.0),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color color) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("GHOST_FINDER MK-III", 
                style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 18)),
              Text("SECTOR: 7-G / ALPHA-SITE", style: TextStyle(color: color.withOpacity(0.5), fontSize: 10)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(4)),
            child: const BlinkingText(text: "LIVE FEED", color: Colors.redAccent),
          )
        ],
      ),
    );
  }

  Widget _buildTargetBlip(TargetNode target, double radius, Color hudGreen) {
    final double x = radius * target.distance * math.cos(target.angle - (math.pi / 2));
    final double y = radius * target.distance * math.sin(target.angle - (math.pi / 2));
    final bool isSelected = _selectedTargetId == target.id;

    return Transform.translate(
      offset: Offset(x, y),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _selectedTargetId = target.id);
          _addLog("LOCK_ACQUIRED: ${target.id}");
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 24 : 12,
              height: isSelected ? 24 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: target.status == 'CRITICAL' ? Colors.redAccent : hudGreen,
                boxShadow: [
                  BoxShadow(
                    color: (target.status == 'CRITICAL' ? Colors.redAccent : hudGreen).withOpacity(0.8),
                    blurRadius: isSelected ? 15 : 5,
                    spreadRadius: isSelected ? 4 : 1,
                  )
                ],
                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: isSelected ? const Icon(Icons.gps_fixed, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(Color hudGreen) {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border.all(color: hudGreen.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Terminal Log
          Expanded(
            flex: 2,
            child: ListView.builder(
              controller: _terminalScroll,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, i) => Text(
                _logs[i],
                style: TextStyle(color: hudGreen.withOpacity(0.7), fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          VerticalDivider(color: hudGreen.withOpacity(0.5), width: 1),
          // Details Panel
          Expanded(
            child: _selectedTargetId == null 
              ? Center(child: Text("NO TARGET", style: TextStyle(color: hudGreen.withOpacity(0.3))))
              : _buildDetailView(hudGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(Color color) {
    final target = _targets.firstWhere((t) => t.id == _selectedTargetId);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SUBJ: ${target.id}", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24),
          _statText("HR/BPM", "${target.heartRate}", target.heartRate > 100 ? Colors.redAccent : color),
          _statText("BATTERY", "${target.battery}%", target.battery < 20 ? Colors.orange : color),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 36),
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _addLog("SIGNAL_PING_SENT -> ${target.id}");
            },
            child: const Text("SEND PING", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _statText(String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(value, style: TextStyle(color: valColor, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- CUSTOM PAINTERS ---

class RadarPainter extends CustomPainter {
  final double rotation;
  final Color color;
  RadarPainter(this.rotation, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), paint);
    }

    // Draw sweep beam
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [Colors.transparent, color.withOpacity(0.5), Colors.transparent],
        stops: const [0.0, 0.5, 0.5],
        transform: GradientRotation(rotation * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, Paint()..shader = sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => oldDelegate.rotation != rotation;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green.withOpacity(0.05)..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    super.initState();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _c, child: Text(widget.text, style: TextStyle(color: widget.color, fontSize: 10, fontWeight: FontWeight.bold)));
}
