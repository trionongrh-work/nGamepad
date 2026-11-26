import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngamepad/main.dart';
import 'package:ngamepad/models/hid_status.dart';
import 'package:ngamepad/widgets/intro_step_view.dart';

void main() {
  test('HidStatusSnapshot.fromMap parses paired hosts and connection state', () {
    final snapshot = HidStatusSnapshot.fromMap({
      'bluetoothAvailable': true,
      'bluetoothEnabled': true,
      'permissionsGranted': true,
      'hidSupported': true,
      'appRegistered': true,
      'connectionState': 'connected',
      'connectedHostName': 'Windows-PC',
      'connectedHostAddress': 'AA:BB:CC:DD:EE:FF',
      'pollingHz': 125,
      'diagnosticMessage': 'Connected to Windows-PC',
      'pairedDevices': [
        {
          'name': 'Windows-PC',
          'address': 'AA:BB:CC:DD:EE:FF',
          'isConnected': true,
        },
      ],
    });

    expect(snapshot.connectionState, HidConnectionState.connected);
    expect(snapshot.connectedHostName, 'Windows-PC');
    expect(snapshot.pollingHz, 125);
    expect(snapshot.pairedDevices.length, 1);
    expect(snapshot.pairedDevices.first.isConnected, isTrue);
  });

  test('GamepadTelemetry.fromMap parses buttons and axes', () {
    final telemetry = GamepadTelemetry.fromMap({
      'buttons': 0x0005, // A (bit 0) + X (bit 2)
      'hat': 2,
      'lx': -127,
      'ly': 127,
      'rx': 0,
      'ry': -64,
      'l2': 200,
      'r2': 0,
      'usbConnected': true,
      'usbDeviceName': 'GameSir-X2 Pro',
    });

    expect(telemetry.isButtonPressed(0), isTrue);
    expect(telemetry.isButtonPressed(1), isFalse);
    expect(telemetry.isButtonPressed(2), isTrue);
    expect(telemetry.lx, -127);
    expect(telemetry.l2, 200);
    expect(telemetry.usbConnected, isTrue);
    expect(telemetry.usbDeviceName, 'GameSir-X2 Pro');
  });

  testWidgets('NgamepadApp renders bridge title and telemetry panel',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NgamepadApp());
    expect(find.text('nGamepad Bridge'), findsOneWidget);
    expect(find.text('LIVE INPUT TELEMETRY'), findsOneWidget);
    expect(find.text('BRIDGE TUNING & DOCKED UX'), findsOneWidget);
  });

  testWidgets('IntroStepView steps through onboarding and calls onFinish',
      (WidgetTester tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: IntroStepView(onFinish: () => finished = true),
      ),
    );

    expect(find.text('Dock Your USB-C Gamepad'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Pair Over Bluetooth HID'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Tune & Lock Your OLED Screen'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(finished, isTrue);
  });
}
