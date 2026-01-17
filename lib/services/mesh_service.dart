import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart'; // Import this

class MeshService {
  final Strategy strategy =
      Strategy.P2P_CLUSTER; // Allows M-to-N connection (Mesh-like)
  String userName = "Ghost_User"; // Replace with dynamic name later

  // 1. VICTIM MODE: Start Screaming Digitally
  Future<void> startBroadcastingSOS() async {
    try {
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          // Accept anyone who tries to connect (Rescuers)
          Nearby().acceptConnection(id, onPayLoadRecieved: (endId, payload) {
            // We can receive "Help is coming" messages here
          });
        },
        onConnectionResult: (id, status) {
          print("Connection Status: $status");
        },
        onDisconnected: (id) {
          print("Disconnected: $id");
        },
        serviceId: "com.example.ghost_signal", // Unique ID for our app
      );
      print("GHOST MESH: Broadcasting Started? $a");
    } catch (e) {
      print("Error Broadcasting: $e");
    }
  }

  // 2. RESCUER MODE: Start Searching
  Future<void> startScanning() async {
    try {
      bool a = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (String id, String name, String serviceId) {
          // FOUND A VICTIM!
          print("GHOST SIGNAL DETECTED: $name ($id)");

          // Connect automatically to pull their data
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (id, info) {
              Nearby().acceptConnection(id,
                  onPayLoadRecieved: (endId, payload) {
                // DATA RECEIVED from Victim
                String message = String.fromCharCodes(payload.bytes!);
                print("SOS PAYLOAD: $message");
              });
            },
            onConnectionResult: (id, status) {
              print("Connected to Victim: $status");
            },
            onDisconnected: (id) {},
          );
        },
        onEndpointLost: (id) {
          print("Lost signal: $id");
        },
        serviceId: "com.example.ghost_signal",
      );
      print("GHOST MESH: Scanning Started? $a");
    } catch (e) {
      print("Error Scanning: $e");
    }
  }

  // 3. SEND DATA (The Payload)
  void sendEmergencyPayload(
      String endpointId, String lat, String long, String trigger) {
    String message = jsonEncode({
      "type": "SOS",
      "lat": lat,
      "long": long,
      "trigger": trigger,
      "time": DateTime.now().toIso8601String(),
    });

    Nearby()
        .sendBytesPayload(endpointId, Uint8List.fromList(message.codeUnits));
  }

  // 4. FIXED PERMISSION CHECKER
  Future<void> checkPermissions() async {
    // We request ALL necessary permissions for modern Android (12+)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices, // Critical for P2P_CLUSTER
    ].request();

    if (statuses[Permission.location]!.isDenied ||
        statuses[Permission.bluetoothScan]!.isDenied) {
      print("CRITICAL: Permissions denied. Mesh will not work.");
    }
  }
}
