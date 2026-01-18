import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghostsignal/main.dart';

class DisclosureScreen extends StatefulWidget {
  const DisclosureScreen({super.key});

  @override
  State<DisclosureScreen> createState() => _DisclosureScreenState();
}

class _DisclosureScreenState extends State<DisclosureScreen> {
  bool _hasScrolledToBottom = false;
  bool _confirmedSensors = false;

  void _accept(BuildContext context) async {
    if (!_confirmedSensors) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms', true);
    
    // Using a FadeTransition for a "high-tech" feel
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const GhostDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep obsidian
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Colors.red.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_update_good, color: Colors.redAccent, size: 50),
                const SizedBox(height: 25),
                const Text(
                  "SECURITY\nDISCLOSURE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.black,
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  height: 2,
                  width: 60,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 30),
                
                // Detailed Disclosure List
                Expanded(
                  child: ListView(
                    children: [
                      _disclosureItem(
                        Icons.sensors, 
                        "Sensor Monitoring", 
                        "Accesses accelerometer and gyroscope to detect high-impact collisions or falls automatically."
                      ),
                      _disclosureItem(
                        Icons.location_on, 
                        "Critical Location", 
                        "Transmits your exact coordinates to emergency contacts only when a crisis is triggered."
                      ),
                      _disclosureItem(
                        Icons.record_voice_over, 
                        "Voice Activation", 
                        "Listens for specific distress keywords in high-risk environments."
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Your data is encrypted locally. Ghost Signal does not sell your safety data to third parties.",
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                
                // Interactive Confirmation
                GestureDetector(
                  onTap: () => setState(() => _confirmedSensors = !_confirmedSensors),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _confirmedSensors,
                        onChanged: (val) => setState(() => _confirmedSensors = val!),
                        activeColor: Colors.redAccent,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      const Expanded(
                        child: Text(
                          "I confirm that I am 18+ and grant full sensor access for safety monitoring.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _confirmedSensors ? Colors.redAccent : Colors.grey[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _confirmedSensors ? () => _accept(context) : null,
                    child: Text(
                      "ACTIVATE PROTOCOL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _confirmedSensors ? Colors.white : Colors.white24,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _disclosureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
