# Ghost Signal(name change)
(emergency)---
---
## Features
- **SOS Button:** Manual trigger for emergencies.
- **High Alert Detection:** Detects natural disasters (earthquake, landslide) via APIs.
- **Accident Detection:** Uses accelerometer and gyroscope to detect sudden impact.
- **Countdown Timer:** 15-second emergency countdown with **I’m Safe / Help Me** options.
- **Automatic Emergency Messaging:** Sends alerts to multiple emergency contacts if the user cannot respond.
- **Bluetooth SOS:** Nearby devices can be notified even without network.
- **Siren & Flashlight:** Activates to attract attention.
- **Text-to-Speech Alerts:** Automated voice prompts simulate IVR for user confirmation.
- **Profile Management:** Save your name and multiple emergency contacts.
---
## Installation
1. **Clone the repository**
```bash
git clone <your-repo-url>
cd ghost_signal
cd ghost_signal
```
2.  **Install dependencies**
```
flutter pub get
```
4. **Run The app**
```
flutter run
```
# Required Permissions
### For Android:
```
<uses-permission android:name="android.permission.READ_CONTACTS"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```
### For iOS (Info.plist):
```
<key>NSContactsUsageDescription</key>
<string>Access contacts to notify emergency contacts.</string>
<key>NSCameraUsageDescription</key>
<string>Access flashlight for emergency alert.</string>
```
# Packages Used

flutter_tts – Text-to-Speech for voice prompts

flutter_contacts – Access and select emergency contacts

shared_preferences – Save user profile and contacts locally

sensors_plus – Accelerometer & gyroscope for accident detection

flutter_bluetooth_serial – Send SOS messages to nearby devices

torch_light – Flashlight control

audioplayers – Play siren audio
## Project structure
```
lib/
├─ screens/
│  ├─ home_screen.dart
│  ├─ profile_screen.dart
│  ├─ messages_screen.dart
│  └─ sos_countdown_screen.dart
├─ services/
│  ├─ emergency_service.dart
│  ├─ bluetooth_service.dart
│  └─ accident_detection_service.dart
└─ main.dart
```
# How It Works
- User opens the app and sets up name and emergency contacts in Profile.
- User presses SOS button or a high-alert event is detected.
- Countdown starts (15 sec) with siren, flashlight, and TTS prompt:
“Press 1 if safe, press 2 if you need help.”
- User presses I’m Safe → All stops
- User presses Help Me → Messages sent to emergency contacts
- No action → Automatic emergency messages sent
### Notes
App works offline using Bluetooth to alert nearby devices.

Multiple emergency contacts supported.

Designed for quick response during disasters in Nepal.

### License
```
This project is private for hackathon use and not published publicly.


---

******************************************************************************************compltedddd!!***************************************************************************************************************
