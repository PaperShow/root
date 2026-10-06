import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../utils/app_fonts.dart';
import '../utils/launcher_tips.dart';
import '../widgets/digital_grain.dart';

class _Slide {
  final IconData icon;
  final String? title;
  final List<String>? bullets;
  final ThemeTip? tip;

  const _Slide({required this.icon, this.title, this.bullets, this.tip});

  String get displayTitle => tip?.title ?? title!;
  List<String> get displayBullets => tip?.bullets ?? bullets!;
}

final List<_Slide> _kSlides = [
  const _Slide(
    icon: Icons.waving_hand_outlined,
    title: 'RootL Launcher',
    bullets: [
      'minimalist command-line interface & authentic phone launcher',
      'integrated AI Assistant for instant natural queries',
      'built-in Habit Tracker commit board (swipe left)',
    ],
  ),
  _Slide(icon: Icons.terminal, tip: kThemeTips[LauncherThemeType.terminal]),
  _Slide(
    icon: Icons.phone_android_outlined,
    tip: kThemeTips[LauncherThemeType.standard],
  ),
  const _Slide(icon: Icons.touch_app_outlined, tip: kUniversalTips),
];

class WalkthroughScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final VoidCallback onDone;

  const WalkthroughScreen({
    super.key,
    required this.themeProvider,
    required this.onDone,
  });

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    widget.themeProvider.markWalkthroughSeen();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _kSlides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DigitalGrain(
        opacity: 0.08,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'skip',
                    style: AppFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: _kSlides.map(_buildSlide).toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_kSlides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: active ? 0.8 : 0.25,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          isLast ? 'done' : 'next',
                          style: AppFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            slide.icon,
            color: Colors.white.withValues(alpha: 0.8),
            size: 40,
          ),
          const SizedBox(height: 24),
          Text(
            slide.displayTitle,
            style: AppFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 24),
          for (final bullet in slide.displayBullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '·  ',
                    style: AppFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: AppFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
