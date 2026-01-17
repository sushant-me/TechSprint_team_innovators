import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghostsignal/main.dart';

class DisclosureScreen extends StatelessWidget {
  const DisclosureScreen({super.key});

  void _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_terms', true);
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => const GhostDashboard()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield, color: Colors.redAccent, size: 60),
              const SizedBox(height: 20),
              const Text("EMERGENCY PROTOCOL",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text(
                  "Ghost Signal is an automated crisis response tool. By proceeding, you grant access to device sensors.",
                  style: TextStyle(color: Colors.grey)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () => _accept(context),
                  child: const Text("I UNDERSTAND & GRANT ACCESS",
                      style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
