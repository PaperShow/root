import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../styles/app_theme.dart';
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
  final AuthService _authService = AuthService();
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _proceedToApp({bool isGoogle = false, String? userName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome_screen', true);
    if (isGoogle) {
      await prefs.setString('user_auth_provider', 'google');
      if (userName != null) {
        await prefs.setString('user_name', userName);
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SuperAppHubScreen(themeProvider: widget.themeProvider),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final User? user = await _authService.signInWithGoogle();
      if (user != null) {
        final displayName = user.displayName ?? user.email?.split('@').first ?? 'User';
        await _proceedToApp(isGoogle: true, userName: displayName);
      } else {
        // Cancelled by user
        if (mounted) {
          setState(() {
            _isSigningIn = false;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _errorMessage = e.message ?? e.code;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _errorMessage = 'Sign in failed. Check network or continue as guest.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isLight = theme.isLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackground,
      body: DigitalGrain(
        opacity: isLight ? 0.02 : 0.06,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Theme Switcher
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: theme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      widget.themeProvider.setAppThemeMode(
                        isLight ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),

                const Spacer(flex: 3),

                // ─── MINIMAL LOGO & BRANDING ──────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/images/root_icon_load.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, stackTrace) => Icon(
                          Icons.terminal_rounded,
                          color: theme.textPrimary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'root',
                  style: AppFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'minimal launcher & tools',
                  style: AppFonts.inter(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.expenseCoral.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppFonts.inter(
                        color: theme.expenseCoral,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const Spacer(flex: 4),

                // ─── GOOGLE LOGIN BUTTON WITH ASSET ICON ─────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.card,
                      foregroundColor: theme.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.border, width: 1.2),
                      ),
                    ),
                    onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                    child: _isSigningIn
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.textPrimary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, error, stackTrace) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'continue with google',
                                style: AppFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 0.5,
                                  color: theme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── GUEST / SKIP BUTTON ───────────────────────
                TextButton(
                  onPressed: () => _proceedToApp(isGoogle: false),
                  child: Text(
                    'continue as guest',
                    style: AppFonts.inter(
                      color: theme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
