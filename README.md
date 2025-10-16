# Speedy Cricket

A minimal Flutter app to measure cricket bowling speed using a simple start/end timer.

## Run (Windows PowerShell)

Ensure you have Flutter installed and on your PATH.

```powershell
cd \workspace\speedy_cricket
flutter pub get
flutter run -d windows
```

If you don't have Windows desktop support enabled, run on an attached device or emulator:

```powershell
flutter devices
flutter run
```

## Usage
- Set pitch length (default 20.12 m = 22 yards).
- Tap Start when you release the ball.
- Tap End when the ball reaches the batsman.
- The app shows speed in km/h.

Notes: This measures elapsed time between taps; accuracy depends on human timing. For better results, use a high-frame-rate camera or dedicated sensors.
