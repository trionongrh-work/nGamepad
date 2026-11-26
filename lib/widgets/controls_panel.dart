import 'package:flutter/material.dart';

import '../state/gamepad_controller.dart';

class ControlsPanel extends StatelessWidget {
  const ControlsPanel({
    super.key,
    required this.controller,
  });

  final GamepadController controller;

  static const List<int> _pollingOptions = [60, 90, 120, 125];

  @override
  Widget build(BuildContext context) {
    final deadzonePct = (controller.deadzone * 100).round();

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
          const Text(
            'BRIDGE TUNING & DOCKED UX',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Stick Deadzone',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '$deadzonePct%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            value: controller.deadzone,
            min: 0.0,
            max: 0.30,
            divisions: 30,
            onChanged: controller.updateDeadzone,
          ),
          const SizedBox(height: 6),
          const Text(
            'HID Polling Rate',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _pollingOptions.map((hz) {
              final selected = controller.pollingHz == hz;
              return ChoiceChip(
                label: Text('${hz}Hz'),
                selected: selected,
                onSelected: (_) => controller.updatePollingRate(hz),
                selectedColor:
                    const Color(0xFF00E5FF).withValues(alpha: 0.22),
                labelStyle: TextStyle(
                  color: selected ? const Color(0xFF00E5FF) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const Divider(color: Color(0xFF1E212B), height: 22),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Keep Screen Awake',
              style: TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Prevents Android from sleeping while bridged',
              style: TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
            value: controller.keepScreenOn,
            onChanged: controller.setKeepScreenOn,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => controller.setOledLock(true),
              icon: const Icon(Icons.brightness_2_rounded, size: 18),
              label: const Text('Enter OLED Dim & Touch Lock Mode'),
            ),
          ),
        ],
      ),
    );
  }
}
