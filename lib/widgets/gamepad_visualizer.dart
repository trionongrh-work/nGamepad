import 'package:flutter/material.dart';

import '../models/hid_status.dart';

class GamepadVisualizer extends StatelessWidget {
  const GamepadVisualizer({
    super.key,
    required this.telemetry,
  });

  final GamepadTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
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
              const Expanded(
                child: Text(
                  'LIVE INPUT TELEMETRY',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '0x${telemetry.buttons.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Analog Triggers L2 / R2 + Bumpers L1 / R1
          Row(
            children: [
              Expanded(
                child: _TriggerBar(
                  label: 'L2',
                  value: telemetry.l2,
                  pressed: telemetry.isButtonPressed(6),
                ),
              ),
              const SizedBox(width: 8),
              _ButtonPill(
                label: 'L1',
                pressed: telemetry.isButtonPressed(4),
              ),
              const SizedBox(width: 8),
              _ButtonPill(
                label: 'R1',
                pressed: telemetry.isButtonPressed(5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TriggerBar(
                  label: 'R2',
                  value: telemetry.r2,
                  pressed: telemetry.isButtonPressed(7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Main layout: Left Stick + D-Pad | Center Meta | ABXY + Right Stick
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              if (compact) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StickPad(
                          label: 'LS',
                          x: telemetry.lx,
                          y: telemetry.ly,
                          clicked: telemetry.isButtonPressed(10),
                        ),
                        _StickPad(
                          label: 'RS',
                          x: telemetry.rx,
                          y: telemetry.ry,
                          clicked: telemetry.isButtonPressed(11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _DpadCross(hat: telemetry.hat),
                        _AbxyDiamond(telemetry: telemetry),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StickPad(
                    label: 'LS',
                    x: telemetry.lx,
                    y: telemetry.ly,
                    clicked: telemetry.isButtonPressed(10),
                  ),
                  _DpadCross(hat: telemetry.hat),
                  _AbxyDiamond(telemetry: telemetry),
                  _StickPad(
                    label: 'RS',
                    x: telemetry.rx,
                    y: telemetry.ry,
                    clicked: telemetry.isButtonPressed(11),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // System & extra buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _ButtonPill(
                label: 'SELECT',
                pressed: telemetry.isButtonPressed(8),
              ),
              _ButtonPill(
                label: 'HOME',
                pressed: telemetry.isButtonPressed(12),
              ),
              _ButtonPill(
                label: 'START',
                pressed: telemetry.isButtonPressed(9),
              ),
              _ButtonPill(
                label: 'L3',
                pressed: telemetry.isButtonPressed(10),
              ),
              _ButtonPill(
                label: 'R3',
                pressed: telemetry.isButtonPressed(11),
              ),
              _ButtonPill(
                label: 'M1',
                pressed: telemetry.isButtonPressed(13),
              ),
              _ButtonPill(
                label: 'M2',
                pressed: telemetry.isButtonPressed(14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriggerBar extends StatelessWidget {
  const _TriggerBar({
    required this.label,
    required this.value,
    required this.pressed,
  });

  final String label;
  final int value;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / 255.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: pressed ? const Color(0xFF00E5FF) : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: const Color(0xFF1A1D26),
            valueColor: AlwaysStoppedAnimation<Color>(
              pressed ? const Color(0xFF00E5FF) : const Color(0xFF3A7BD5),
            ),
          ),
        ),
      ],
    );
  }
}

class _StickPad extends StatelessWidget {
  const _StickPad({
    required this.label,
    required this.x,
    required this.y,
    required this.clicked,
  });

  final String label;
  final int x;
  final int y;
  final bool clicked;

  @override
  Widget build(BuildContext context) {
    const double size = 86;
    final nx = (x / 127.0).clamp(-1.0, 1.0);
    final ny = (y / 127.0).clamp(-1.0, 1.0);

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF14161D),
            border: Border.all(
              color: clicked
                  ? const Color(0xFF00E676)
                  : const Color(0xFF292E3B),
              width: clicked ? 2 : 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 1,
                height: size - 16,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Container(
                width: size - 16,
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Transform.translate(
                offset: Offset(nx * 26, ny * 26),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: clicked
                        ? const Color(0xFF00E676)
                        : const Color(0xFF00E5FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$label ($x, $y)',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _DpadCross extends StatelessWidget {
  const _DpadCross({required this.hat});

  final int hat;

  @override
  Widget build(BuildContext context) {
    final up = hat == 0 || hat == 1 || hat == 7;
    final right = hat == 1 || hat == 2 || hat == 3;
    final down = hat == 3 || hat == 4 || hat == 5;
    final left = hat == 5 || hat == 6 || hat == 7;

    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, child: _DpadCell(active: up, label: '▲')),
          Positioned(bottom: 0, child: _DpadCell(active: down, label: '▼')),
          Positioned(left: 0, child: _DpadCell(active: left, label: '◀')),
          Positioned(right: 0, child: _DpadCell(active: right, label: '▶')),
        ],
      ),
    );
  }
}

class _DpadCell extends StatelessWidget {
  const _DpadCell({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF00E5FF) : const Color(0xFF171922),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? const Color(0xFF00E5FF) : const Color(0xFF2A2F3D),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? Colors.black : Colors.white54,
        ),
      ),
    );
  }
}

class _AbxyDiamond extends StatelessWidget {
  const _AbxyDiamond({required this.telemetry});

  final GamepadTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _FaceButton(
              label: 'Y',
              color: const Color(0xFFFFD740),
              pressed: telemetry.isButtonPressed(3),
            ),
          ),
          Positioned(
            bottom: 0,
            child: _FaceButton(
              label: 'A',
              color: const Color(0xFF00E676),
              pressed: telemetry.isButtonPressed(0),
            ),
          ),
          Positioned(
            left: 0,
            child: _FaceButton(
              label: 'X',
              color: const Color(0xFF40C4FF),
              pressed: telemetry.isButtonPressed(2),
            ),
          ),
          Positioned(
            right: 0,
            child: _FaceButton(
              label: 'B',
              color: const Color(0xFFFF5252),
              pressed: telemetry.isButtonPressed(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
    required this.label,
    required this.color,
    required this.pressed,
  });

  final String label;
  final Color color;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pressed ? color : const Color(0xFF171922),
        border: Border.all(
          color: pressed ? color : color.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: pressed ? Colors.black : color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ButtonPill extends StatelessWidget {
  const _ButtonPill({
    required this.label,
    required this.pressed,
  });

  final String label;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pressed ? const Color(0xFF00E5FF) : const Color(0xFF151720),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pressed ? const Color(0xFF00E5FF) : const Color(0xFF282C3A),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: pressed ? Colors.black : Colors.white60,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
