import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/hid_status.dart';
import '../services/ngamepad_bridge.dart';

class GamepadController extends ChangeNotifier {
  GamepadController({NgamepadBridge? bridge})
      : _bridge = bridge ?? NgamepadBridge();

  final NgamepadBridge _bridge;

  StreamSubscription<HidStatusSnapshot>? _statusSub;
  StreamSubscription<GamepadTelemetry>? _telemetrySub;

  HidStatusSnapshot status = const HidStatusSnapshot.initial();
  GamepadTelemetry telemetry = const GamepadTelemetry.empty();

  double deadzone = 0.08;
  int pollingHz = 120;
  bool keepScreenOn = true;
  bool oledLockActive = false;
  bool showIntro = false;

  void start() {
    _statusSub ??= _bridge.statusStream.listen((snapshot) {
      status = snapshot;
      pollingHz = snapshot.pollingHz;
      notifyListeners();
    });
    _telemetrySub ??= _bridge.telemetryStream.listen((data) {
      telemetry = data;
      notifyListeners();
    });
    _loadIntroStatus();
  }

  Future<void> _loadIntroStatus() async {
    final completed = await _bridge.getIntroCompleted();
    if (!completed) {
      showIntro = true;
      notifyListeners();
    }
  }

  void openIntro() {
    showIntro = true;
    notifyListeners();
  }

  Future<void> completeIntro() async {
    showIntro = false;
    notifyListeners();
    await _bridge.setIntroCompleted(true);
  }

  Future<void> requestPermissionsAndInit() async {
    final granted = await _bridge.requestPermissions();
    if (granted) {
      status = await _bridge.initialize();
      notifyListeners();
    }
  }

  Future<void> retryInitialize() async {
    status = await _bridge.initialize();
    notifyListeners();
  }

  Future<void> connectHost(String address) => _bridge.connectHost(address);

  Future<void> disconnectHost() => _bridge.disconnectHost();

  Future<void> requestDiscoverable() => _bridge.requestDiscoverable();

  Future<void> updateDeadzone(double value) async {
    deadzone = value.clamp(0.0, 0.35);
    notifyListeners();
    await _bridge.setDeadzone(deadzone);
  }

  Future<void> updatePollingRate(int hz) async {
    pollingHz = hz;
    notifyListeners();
    await _bridge.setPollingRate(hz);
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenOn = enabled;
    notifyListeners();
    await _bridge.setKeepScreenOn(enabled);
  }

  Future<void> setOledLock(bool enabled) async {
    oledLockActive = enabled;
    notifyListeners();
    await _bridge.setOledDim(enabled);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    super.dispose();
  }
}
