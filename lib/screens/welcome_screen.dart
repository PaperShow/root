import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../utils/app_fonts.dart';
import '../widgets/digital_grain.dart';
import 'super_app_hub_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const WelcomeScreen({super.key, required this.themeProvider});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF101010);
  static const Color surfaceBorder = Color(0xFF222222);

  bool _isSigningIn = false;

  Future<void> _proceedToApp({bool isGoogle = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome_screen', true);
    if (isGoogle) {
      await prefs.setString('user_auth_provider', 'google');
      await prefs.setString('user_name', 'Google User');
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SuperAppHubScreen(themeProvider: widget.themeProvider),
        ),
      );
    }
  }

  void _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });

    // Simulated quick feedback
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: terminalGreen, size: 18),
              const SizedBox(width: 10),
              Text(
                'Signed in with Google (UI Ready)',
                style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      _proceedToApp(isGoogle: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureBlack,
      body: DigitalGrain(
        opacity: 0.08,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),

                // ─── LOGO & BRANDING ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    shape: BoxShape.circle,
                    border: Border.all(color: terminalGreen.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: terminalGreen.withValues(alpha: 0.2),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/root_icon_load.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) => const Icon(
                      Icons.terminal,
                      color: terminalGreen,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'RootL',
                  style: AppFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'minimalist launcher & modular tools suite',
                  style: AppFonts.inter(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // ─── HIGHLIGHT FEATURES ────────────────────────
                _buildFeatureItem(Icons.account_balance_wallet_outlined, 'Expense Tracker & Splitwise Groups'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.checklist_rtl, 'Daily Habit Tracker & Streaks'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.volume_up_outlined, 'Floating Volume Controller Over All Apps'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.phone_android, 'Terminal & Standard Minimalist Launcher'),

                const Spacer(flex: 3),

                // ─── GOOGLE LOGIN BUTTON ───────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                    child: _isSigningIn
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGoogleIcon(),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: AppFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── GUEST / SKIP BUTTON ───────────────────────
                TextButton(
                  onPressed: () => _proceedToApp(isGoogle: false),
                  child: Text(
                    'Skip for now • Continue as Guest',
                    style: AppFonts.jetBrainsMono(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: terminalGreen, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppFonts.inter(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleIconPainter(),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draws clean 4-color Google G icon
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.38, w * 0.55, h * 0.24), paint);

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawCircle(Offset(w * 0.5, h * 0.82), w * 0.18, paint);

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawCircle(Offset(w * 0.18, h * 0.5), w * 0.18, paint);

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawCircle(Offset(w * 0.5, h * 0.18), w * 0.18, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
