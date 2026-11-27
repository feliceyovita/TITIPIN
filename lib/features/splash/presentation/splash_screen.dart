import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../auth/register_login/login_screen.dart';
import '../../catalog/catalog_screen.dart';
import '../../auth/data/firebase_auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _splashDuration =
  Duration(milliseconds: 1800);

  static const _sessionTimeout = Duration(seconds: 8);

  static const Duration _animationDuration =
  Duration(milliseconds: 700);

  late final Timer _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(_splashDuration, _navigateToLogin);
  }

  @override
  void dispose() {
    _splashTimer.cancel();
    super.dispose();
  }

  Future<void> _navigateToLogin() async {
    if (!mounted) return;

    bool verifiedSession = false;
    try {
      verifiedSession = await FirebaseAuthService.instance
          .hasVerifiedSession()
          .timeout(_sessionTimeout);
    } catch (error) {
      debugPrint('[SPLASH] Pemeriksaan sesi gagal (${error.runtimeType}).');
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => verifiedSession
            ? const CatalogScreen()
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ukuran logo menyesuaikan lebar dan tinggi layar.
            // Maksimal 200 logical pixels.
            final double logoSize = math.min(
              200.0,
              math.min(
                constraints.maxWidth * 0.50,
                constraints.maxHeight * 0.32,
              ),
            );

            return Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ),
                duration: _animationDuration,
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) {
                  return Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.92 + (0.08 * progress),
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/titipin_logo.png',
                  key: const ValueKey('titipin_logo'),
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo Titipin',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
