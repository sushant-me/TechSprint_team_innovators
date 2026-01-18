import 'package:telephony/telephony.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;

  Future<void> sendBackgroundSms(
      List<String> recipients, String lat, String long) async {
    bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != true) return;

    // Use Google Maps Link format that works
    String message =
        "SOS! I need help. My location: https://www.google.com/maps/search/?api=1&query=$lat,$long";

    for (String number in recipients) {
      try {
        await _telephony.sendSms(to: number, message: message);
      } catch (e) {
        print("SMS Failed to $number: $e");
      }
    }
  }
}
