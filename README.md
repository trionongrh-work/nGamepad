# nGamepad

**nGamepad** turns an Android phone docked in a wired USB-C gamepad (such as a **GameSir X2 Pro**) into a wireless **Bluetooth HID Gamepad** for a Windows PC or another Android device — with **zero companion software** required on the target host.

---

## Features

- **Zero-Round-Trip Native Input Pipeline**: USB-C `KeyEvent` and `MotionEvent` inputs are captured in `MainActivity.kt` and fed directly to `BluetoothHidManager.kt` on a dedicated background thread (`60–125 Hz`), keeping Flutter strictly for UI, configuration, and live telemetry.
- **Standard Bluetooth HID Gamepad Profile**: Uses Android's native `BluetoothHidDevice` API (`BluetoothProfile.HID_DEVICE`, `SUBCLASS2_GAMEPAD`) with a 9-byte HID report:
  - **16 Buttons**: A, B, X, Y, L1, R1, L2, R2, Select, Start, L3, R3, Home, M1, M2, Extra
  - **8-Way Hat Switch**: D-Pad (`0..7`, `8` centered)
  - **4 Analog Stick Axes**: Left X/Y (`X`, `Y`) and Right X/Y (`Z`, `Rz`) signed `-127..127` with radial deadzone
  - **2 Linear Analog Triggers**: L2 (`Rx`) and R2 (`Ry`) unsigned `0..255` normalized from each controller's `InputDevice.MotionRange`
- **OEM Compatibility Diagnostics**: Verifies `BluetoothHidDevice` support on startup and surfaces clear permission/ROM status messages.
- **Docked OLED UX**:
  - `FLAG_KEEP_SCREEN_ON` keeps the phone awake while bridging.
  - **OLED Dim & Touch Lock Mode** renders a pure `#000000` overlay at minimal brightness with a 1.5s hold-to-unlock button to prevent accidental palm touches.
  - Interactive **3-step Introduction StepView** on first launch (also accessible anytime via the `?` icon in the top bar).

---

## Project Structure

```text
android/app/src/main/
├── AndroidManifest.xml                                    # BT (API 28-35) & USB Host permissions
├── res/
│   ├── drawable/ic_launcher_background.xml                # Adaptive icon background
│   ├── drawable/ic_launcher_foreground.xml                # Adaptive icon vector foreground
│   └── mipmap-anydpi-v26/ic_launcher*.xml                 # Android Adaptive Icon config
└── kotlin/com/ngamepad/ngamepad/
    ├── HidDescriptor.kt                                   # 9-byte HID descriptor & report packer
    ├── BluetoothHidManager.kt                             # BluetoothHidDevice lifecycle & polling loop
    └── MainActivity.kt                                    # USB input capture, channels, wakelock/dim

lib/
├── main.dart                                              # OLED dark theme & responsive layout
├── models/hid_status.dart                                 # Typed status & telemetry models
├── services/ngamepad_bridge.dart                          # MethodChannel / EventChannel bridge
├── state/gamepad_controller.dart                          # ChangeNotifier state controller
└── widgets/
    ├── intro_step_view.dart                               # 3-step onboarding walkthrough
    ├── status_banner.dart                                 # HID diagnostics & paired host picker
    ├── gamepad_visualizer.dart                            # Live dual-stick, trigger & button tester
    ├── controls_panel.dart                                # Deadzone, polling rate & OLED lock controls
    └── oled_lock_overlay.dart                             # Pure black palm-rejection lock overlay
```

---

## Requirements

- **Android 9.0 (API 28)+** with `BluetoothHidDevice` enabled in the device's OEM ROM.
- **Flutter 3.35+** / Dart 3.9+.
- A wired USB-C or hardware Android gamepad (tested around **GameSir X2 Pro**).

---

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run static analysis & widget/unit tests
flutter analyze
flutter test

# Build debug or release APK
flutter build apk --debug
flutter build apk --release
```

---

## Quick Usage Guide

1. **Dock** your phone into your USB-C gamepad.
2. **Grant Bluetooth permissions** when prompted, then tap **Pair / Discoverable (120s)**.
3. On your **Windows PC** or target **Android device**, open Bluetooth settings and pair with **nGamepad Pro**.
4. Test sticks, triggers, and buttons in the **Live Input Telemetry** panel, tune **Stick Deadzone** and **HID Polling Rate**, and tap **Enter OLED Dim & Touch Lock Mode** while gaming.

---

## License

Personal Use License — see [LICENSE](LICENSE) for details.

