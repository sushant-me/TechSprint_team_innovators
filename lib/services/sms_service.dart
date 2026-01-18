import 'dart:async';
import 'package:telephony/telephony.dart';

enum SmsStatus { sending, delivered, failed }

class LifelineCommLink {
  final Telephony _telephony = Telephony.instance;
  
  // Stream to update UI on delivery status (e.g., show a checkmark)
  final StreamController<Map<String, SmsStatus>> _statusController = 
      StreamController.broadcast();
  Stream<Map<String, SmsStatus>> get deliveryStream => _statusController.stream;

  final Map<String, SmsStatus> _deliveryStatus = {};

  /// Sends a tactical SOS message to multiple contacts
  Future<void> dispatchSos({
    required List<String> recipients, 
    required double lat, 
    required double long,
    String? customMessage
  }) async {
    
    // 1. Permission Check
    bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != true) {
      throw Exception("SMS Permissions Denied. Cannot send SOS.");
    }

    // 2. Construct Robust Payload
    // Uses standard Google Maps schema that opens natively on Android/iOS
    String mapLink = "https://maps.google.com/?q=$lat,$long";
    String baseMsg = customMessage ?? "🚨 SOS! I need immediate help.";
    
    // We keep it under 160 chars if possible to avoid multipart issues in bad coverage
    String finalMessage = "$baseMsg\n\nMy Location:\n$mapLink\n\n(Sent via Ghost Signal)";

    // 3. Reset Status
    _deliveryStatus.clear();
    for (var number in recipients) {
      _deliveryStatus[number] = SmsStatus.sending;
    }
    _statusController.add(_deliveryStatus);

    // 4. Fire the Signals
    for (String number in recipients) {
      await _sendSingleSms(number, finalMessage);
    }
  }

  Future<void> _sendSingleSms(String number, String message) async {
    try {
      await _telephony.sendSms(
        to: number,
        message: message,
        statusListener: (SendStatus status) {
          // This listener tells us if the network accepted the message
          if (status == SendStatus.SENT) {
            print("✅ Network accepted SMS for $number");
            _updateStatus(number, SmsStatus.delivered); // Best guess for "sent"
          } else if (status == SendStatus.DELIVERED) {
            // Note: 'DELIVERED' status requires carrier support and might not fire on all SIMs
            print("🚀 Confirmed delivery to $number");
            _updateStatus(number, SmsStatus.delivered);
          }
        },
        isMultipart: true, // Crucial for long location URLs
      );
    } catch (e) {
      print("❌ SMS FAILED for $number: $e");
      _updateStatus(number, SmsStatus.failed);
    }
  }

  void _updateStatus(String number, SmsStatus status) {
    _deliveryStatus[number] = status;
    _statusController.add(_deliveryStatus);
  }

  void dispose() {
    _statusController.close();
  }
}
