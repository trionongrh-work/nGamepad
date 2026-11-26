import 'package:flutter/services.dart';

import '../models/hid_status.dart';

class NgamepadBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.ngamepad.ngamepad/control');
  static const EventChannel _statusChannel =
      EventChannel('com.ngamepad.ngamepad/status');
  static const EventChannel _telemetryChannel =
      EventChannel('com.ngamepad.ngamepad/telemetry');

  Stream<HidStatusSnapshot> get statusStream =>
      _statusChannel.receiveBroadcastStream().map((event) {
        if (event is Map<Object?, Object?>) {
          return HidStatusSnapshot.fromMap(event);
        }
        return const HidStatusSnapshot.initial();
      });

  Stream<GamepadTelemetry> get telemetryStream =>
      _telemetryChannel.receiveBroadcastStream().map((event) {
        if (event is Map<Object?, Object?>) {
          return GamepadTelemetry.fromMap(event);
        }
        return const GamepadTelemetry.empty();
      });

  Future<HidStatusSnapshot> initialize() async {
    final result =
        await _methodChannel.invokeMapMethod<Object?, Object?>('initialize');
    if (result == null) return const HidStatusSnapshot.initial();
    return HidStatusSnapshot.fromMap(result);
  }

  Future<bool> requestPermissions() async {
    final granted = await _methodChannel.invokeMethod<bool>('requestPermissions');
    return granted ?? false;
  }

  Future<bool> connectHost(String address) async {
    final ok = await _methodChannel.invokeMethod<bool>(
      'connectHost',
      {'address': address},
    );
    return ok ?? false;
  }

  Future<bool> disconnectHost() async {
    final ok = await _methodChannel.invokeMethod<bool>('disconnectHost');
    return ok ?? false;
  }

  Future<bool> requestDiscoverable() async {
    final ok = await _methodChannel.invokeMethod<bool>('requestDiscoverable');
    return ok ?? false;
  }

  Future<void> setDeadzone(double value) async {
    await _methodChannel.invokeMethod<void>('setDeadzone', {'value': value});
  }

  Future<void> setPollingRate(int hz) async {
    await _methodChannel.invokeMethod<void>('setPollingRate', {'hz': hz});
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    await _methodChannel.invokeMethod<void>(
      'setKeepScreenOn',
      {'enabled': enabled},
    );
  }

  Future<void> setOledDim(bool enabled) async {
    await _methodChannel.invokeMethod<void>(
      'setOledDim',
      {'enabled': enabled},
    );
  }

  Future<bool> getIntroCompleted() async {
    try {
      final completed =
          await _methodChannel.invokeMethod<bool>('getIntroCompleted');
      return completed ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  Future<void> setIntroCompleted(bool completed) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'setIntroCompleted',
        {'completed': completed},
      );
    } on MissingPluginException {
      // Ignored in unit/widget tests
    }
  }
}
