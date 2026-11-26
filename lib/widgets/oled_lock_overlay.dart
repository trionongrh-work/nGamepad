import 'dart:async';

import 'package:flutter/material.dart';

/// Pure black (#000000) OLED dim & touch-lock overlay so accidental palm
/// touches while the phone is docked in the GameSir X2 Pro cannot interrupt bridging.
class OledLockOverlay extends StatefulWidget {
  const OledLockOverlay({
    super.key,
    required this.hostName,
    required this.onUnlock,
  });

  final String? hostName;
  final VoidCallback onUnlock;

  @override
  State<OledLockOverlay> createState() => _OledLockOverlayState();
}

class _OledLockOverlayState extends State<OledLockOverlay> {
  Timer? _holdTimer;
  double _progress = 0.0;
  bool _holding = false;

  static const _holdDuration = Duration(milliseconds: 1500);
  static const _tick = Duration(milliseconds: 30);

  void _startHold() {
    _holding = true;
    _progress = 0.0;
    _holdTimer?.cancel();
    final totalTicks =
        _holdDuration.inMilliseconds / _tick.inMilliseconds;
    var currentTick = 0;

    _holdTimer = Timer.periodic(_tick, (timer) {
      currentTick++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = (currentTick / totalTicks).clamp(0.0, 1.0);
      });
      if (_progress >= 1.0) {
        timer.cancel();
        _holding = false;
        widget.onUnlock();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _holding = false;
        _progress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: AbsorbPointer(
        absorbing: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // Swallow stray taps
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.28),
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.hostName != null
                      ? 'Bridging to ${widget.hostName}'
                      : 'OLED Touch Lock Active',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTapDown: (_) => _startHold(),
                  onTapUp: (_) => _cancelHold(),
                  onTapCancel: _cancelHold,
                  child: Container(
                    width: 180,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      color: Colors.white.withValues(alpha: _holding ? 0.08 : 0.03),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progress,
                            heightFactor: 1.0,
                            child: Container(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        Text(
                          _holding ? 'Keep holding...' : 'Hold 1.5s to Unlock',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
