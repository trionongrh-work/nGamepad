import 'package:flutter/material.dart';

import '../models/hid_status.dart';
import '../state/gamepad_controller.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.controller,
  });

  final GamepadController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final telemetry = controller.telemetry;

    final (Color badgeColor, String badgeText, IconData badgeIcon) =
        switch (status.connectionState) {
      HidConnectionState.connected => (
          const Color(0xFF00E676),
          'CONNECTED: ${status.connectedHostName ?? "Host"}',
          Icons.bluetooth_connected_rounded,
        ),
      HidConnectionState.connecting => (
          const Color(0xFFFFD740),
          'CONNECTING...',
          Icons.bluetooth_searching_rounded,
        ),
      HidConnectionState.disconnecting => (
          const Color(0xFFFFAB40),
          'DISCONNECTING...',
          Icons.bluetooth_disabled_rounded,
        ),
      HidConnectionState.disconnected => status.hidSupported
          ? (
              status.appRegistered
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFFFFAB40),
              status.appRegistered ? 'HID READY' : 'SETUP NEEDED',
              Icons.bluetooth_rounded,
            )
          : (
              const Color(0xFFFF5252),
              'HID UNSUPPORTED',
              Icons.error_outline_rounded,
            ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0D11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E212B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 15, color: badgeColor),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.usb_rounded,
                      size: 16,
                      color: telemetry.usbConnected
                          ? const Color(0xFF00E676)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        telemetry.usbConnected
                            ? (telemetry.usbDeviceName ?? 'USB Gamepad')
                            : 'No USB Gamepad',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: telemetry.usbConnected
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.diagnosticMessage,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!status.permissionsGranted)
                FilledButton.icon(
                  onPressed: controller.requestPermissionsAndInit,
                  icon: const Icon(Icons.security_rounded, size: 16),
                  label: const Text('Grant Bluetooth Permissions'),
                )
              else if (!status.appRegistered)
                FilledButton.icon(
                  onPressed: controller.retryInitialize,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry HID Init'),
                ),
              if (status.permissionsGranted && status.bluetoothEnabled)
                OutlinedButton.icon(
                  onPressed: controller.requestDiscoverable,
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('Pair / Discoverable (120s)'),
                ),
              if (status.connectionState == HidConnectionState.connected)
                OutlinedButton.icon(
                  onPressed: controller.disconnectHost,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    side: const BorderSide(color: Color(0x66FF5252)),
                  ),
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Disconnect Host'),
                ),
            ],
          ),
          if (status.pairedDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Paired Hosts (tap to connect)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: status.pairedDevices.map((host) {
                final active = host.isConnected;
                return ActionChip(
                  avatar: Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.computer_rounded,
                    size: 16,
                    color: active ? const Color(0xFF00E676) : Colors.white70,
                  ),
                  label: Text(host.name),
                  backgroundColor: active
                      ? const Color(0xFF00E676).withValues(alpha: 0.14)
                      : const Color(0xFF15171E),
                  side: BorderSide(
                    color: active
                        ? const Color(0xFF00E676).withValues(alpha: 0.5)
                        : const Color(0xFF262A36),
                  ),
                  onPressed: status.appRegistered && !active
                      ? () => controller.connectHost(host.address)
                      : null,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
