import 'package:flutter/material.dart';

class IntroStepView extends StatefulWidget {
  const IntroStepView({
    super.key,
    required this.onFinish,
  });

  final VoidCallback onFinish;

  @override
  State<IntroStepView> createState() => _IntroStepViewState();
}

class _IntroStepViewState extends State<IntroStepView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_IntroStepData> _steps = [
    _IntroStepData(
      stepNumber: 'STEP 1 OF 3',
      title: 'Dock Your USB-C Gamepad',
      description:
          'Connect your Android phone into your GameSir X2 Pro (or any wired USB-C controller). Hardware inputs are captured directly in native Kotlin for ultra-low latency.',
      icon: Icons.usb_rounded,
      accentColor: Color(0xFF00E5FF),
      highlights: [
        'Supports analog sticks, 8-way D-Pad, and linear L2/R2 triggers',
        'Hot-plugging supported — plug or unplug anytime',
      ],
    ),
    _IntroStepData(
      stepNumber: 'STEP 2 OF 3',
      title: 'Pair Over Bluetooth HID',
      description:
          'Grant Bluetooth permissions, tap "Pair / Discoverable (120s)", and connect from your Windows PC or another Android device. Zero companion software needed on the host.',
      icon: Icons.bluetooth_searching_rounded,
      accentColor: Color(0xFF00E676),
      highlights: [
        'Emulates a standard 16-button, 6-axis Bluetooth HID Gamepad',
        'Tap any previously paired host chip to reconnect quickly',
      ],
    ),
    _IntroStepData(
      stepNumber: 'STEP 3 OF 3',
      title: 'Tune & Lock Your OLED Screen',
      description:
          'Verify all inputs in the live visualizer, adjust stick deadzone and polling rate (60–125 Hz), then enable OLED Dim & Touch Lock to prevent accidental palm touches.',
      icon: Icons.brightness_2_rounded,
      accentColor: Color(0xFFFFD740),
      highlights: [
        'Keeps screen awake while bridging is active',
        'Hold 1.5s on the lock button whenever you want to unlock',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    color: Color(0xFF00E5FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'nGamepad Setup',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onFinish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Step progress bar
              Row(
                children: List.generate(_steps.length, (index) {
                  final active = index <= _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index < _steps.length - 1 ? 6 : 0,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: active
                            ? _steps[_currentPage].accentColor
                            : const Color(0xFF1E212B),
                      ),
                    ),
                  );
                }),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _StepCard(data: _steps[index]);
                  },
                ),
              ),
              Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(isLast ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.data});

  final _IntroStepData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0D11),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1E212B)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: data.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: data.accentColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(data.icon, color: data.accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.stepNumber,
                          style: TextStyle(
                            color: data.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                data.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              ...data.highlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: data.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 12.5,
                          ),
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
    );
  }
}

class _IntroStepData {
  const _IntroStepData({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.highlights,
  });

  final String stepNumber;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<String> highlights;
}
