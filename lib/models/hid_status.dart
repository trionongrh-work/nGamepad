enum HidConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting;

  static HidConnectionState fromString(String? value) {
    return switch (value) {
      'connecting' => HidConnectionState.connecting,
      'connected' => HidConnectionState.connected,
      'disconnecting' => HidConnectionState.disconnecting,
      _ => HidConnectionState.disconnected,
    };
  }
}

class PairedHost {
  const PairedHost({
    required this.name,
    required this.address,
    required this.isConnected,
  });

  final String name;
  final String address;
  final bool isConnected;

  factory PairedHost.fromMap(Map<Object?, Object?> map) {
    return PairedHost(
      name: (map['name'] as String?) ?? 'Unknown Device',
      address: (map['address'] as String?) ?? '',
      isConnected: (map['isConnected'] as bool?) ?? false,
    );
  }
}

class HidStatusSnapshot {
  const HidStatusSnapshot({
    required this.bluetoothAvailable,
    required this.bluetoothEnabled,
    required this.permissionsGranted,
    required this.hidSupported,
    required this.appRegistered,
    required this.connectionState,
    required this.connectedHostName,
    required this.connectedHostAddress,
    required this.pollingHz,
    required this.diagnosticMessage,
    required this.pairedDevices,
  });

  const HidStatusSnapshot.initial()
      : bluetoothAvailable = true,
        bluetoothEnabled = false,
        permissionsGranted = false,
        hidSupported = true,
        appRegistered = false,
        connectionState = HidConnectionState.disconnected,
        connectedHostName = null,
        connectedHostAddress = null,
        pollingHz = 120,
        diagnosticMessage = 'Initializing Bluetooth HID...',
        pairedDevices = const [];

  final bool bluetoothAvailable;
  final bool bluetoothEnabled;
  final bool permissionsGranted;
  final bool hidSupported;
  final bool appRegistered;
  final HidConnectionState connectionState;
  final String? connectedHostName;
  final String? connectedHostAddress;
  final int pollingHz;
  final String diagnosticMessage;
  final List<PairedHost> pairedDevices;

  factory HidStatusSnapshot.fromMap(Map<Object?, Object?> map) {
    final rawDevices = map['pairedDevices'];
    final devices = <PairedHost>[];
    if (rawDevices is List) {
      for (final item in rawDevices) {
        if (item is Map<Object?, Object?>) {
          devices.add(PairedHost.fromMap(item));
        }
      }
    }

    return HidStatusSnapshot(
      bluetoothAvailable: (map['bluetoothAvailable'] as bool?) ?? false,
      bluetoothEnabled: (map['bluetoothEnabled'] as bool?) ?? false,
      permissionsGranted: (map['permissionsGranted'] as bool?) ?? false,
      hidSupported: (map['hidSupported'] as bool?) ?? false,
      appRegistered: (map['appRegistered'] as bool?) ?? false,
      connectionState:
          HidConnectionState.fromString(map['connectionState'] as String?),
      connectedHostName: map['connectedHostName'] as String?,
      connectedHostAddress: map['connectedHostAddress'] as String?,
      pollingHz: (map['pollingHz'] as int?) ?? 120,
      diagnosticMessage:
          (map['diagnosticMessage'] as String?) ?? 'Unknown status',
      pairedDevices: devices,
    );
  }
}

class GamepadTelemetry {
  const GamepadTelemetry({
    required this.buttons,
    required this.hat,
    required this.lx,
    required this.ly,
    required this.rx,
    required this.ry,
    required this.l2,
    required this.r2,
    required this.usbConnected,
    required this.usbDeviceName,
  });

  const GamepadTelemetry.empty()
      : buttons = 0,
        hat = 8,
        lx = 0,
        ly = 0,
        rx = 0,
        ry = 0,
        l2 = 0,
        r2 = 0,
        usbConnected = false,
        usbDeviceName = null;

  final int buttons;
  final int hat;
  final int lx;
  final int ly;
  final int rx;
  final int ry;
  final int l2;
  final int r2;
  final bool usbConnected;
  final String? usbDeviceName;

  bool isButtonPressed(int bitIndex) => (buttons & (1 << bitIndex)) != 0;

  factory GamepadTelemetry.fromMap(Map<Object?, Object?> map) {
    return GamepadTelemetry(
      buttons: (map['buttons'] as int?) ?? 0,
      hat: (map['hat'] as int?) ?? 8,
      lx: (map['lx'] as int?) ?? 0,
      ly: (map['ly'] as int?) ?? 0,
      rx: (map['rx'] as int?) ?? 0,
      ry: (map['ry'] as int?) ?? 0,
      l2: (map['l2'] as int?) ?? 0,
      r2: (map['r2'] as int?) ?? 0,
      usbConnected: (map['usbConnected'] as bool?) ?? false,
      usbDeviceName: map['usbDeviceName'] as String?,
    );
  }
}
