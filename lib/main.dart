import 'package:flutter/material.dart';

import 'state/gamepad_controller.dart';
import 'widgets/controls_panel.dart';
import 'widgets/gamepad_visualizer.dart';
import 'widgets/intro_step_view.dart';
import 'widgets/oled_lock_overlay.dart';
import 'widgets/status_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NgamepadApp());
}

class NgamepadApp extends StatelessWidget {
  const NgamepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5FF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'nGamepad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: baseScheme.copyWith(
          surface: const Color(0xFF0C0D11),
          primary: const Color(0xFF00E5FF),
        ),
      ),
      home: const NgamepadHomePage(),
    );
  }
}

class NgamepadHomePage extends StatefulWidget {
  const NgamepadHomePage({super.key});

  @override
  State<NgamepadHomePage> createState() => _NgamepadHomePageState();
}

class _NgamepadHomePageState extends State<NgamepadHomePage> {
  late final GamepadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GamepadController()..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.oledLockActive) {
          return OledLockOverlay(
            hostName: _controller.status.connectedHostName,
            onUnlock: () => _controller.setOledLock(false),
          );
        }

        if (_controller.showIntro) {
          return IntroStepView(
            onFinish: _controller.completeIntro,
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            title: const Row(
              children: [
                Icon(Icons.sports_esports_rounded, color: Color(0xFF00E5FF)),
                SizedBox(width: 10),
                Text(
                  'nGamepad Bridge',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Setup Guide',
                onPressed: _controller.openIntro,
                icon: const Icon(Icons.help_outline_rounded),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '${_controller.pollingHz}Hz',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth >= 700;
                if (isLandscape) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              StatusBanner(controller: _controller),
                              const SizedBox(height: 12),
                              ControlsPanel(controller: _controller),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: GamepadVisualizer(
                            telemetry: _controller.telemetry,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      StatusBanner(controller: _controller),
                      const SizedBox(height: 12),
                      GamepadVisualizer(telemetry: _controller.telemetry),
                      const SizedBox(height: 12),
                      ControlsPanel(controller: _controller),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
