import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scan_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ================================================================
  // COLORS
  // ================================================================

  static const Color _background = Color(0xFF050505);

  // ================================================================
  // ANIMATIONS
  // ================================================================

  late AnimationController _flameController;
  late AnimationController _textController;

  late Animation<double> _flameOpacity;
  late Animation<double> _flameScale;
  late Animation<double> _flameMove;

  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  Timer? _navigationTimer;

  // ================================================================
  // INIT
  // ================================================================

  @override
  void initState() {
    super.initState();

    _setFullScreen();

    // ============================================================
    // FLAME ANIMATION
    // ============================================================

    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);

    _flameOpacity = Tween<double>(
      begin: 0.72,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _flameController,
        curve: Curves.easeInOut,
      ),
    );

    _flameScale = Tween<double>(
      begin: 0.96,
      end: 1.06,
    ).animate(
      CurvedAnimation(
        parent: _flameController,
        curve: Curves.easeInOut,
      ),
    );

    _flameMove = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(
      CurvedAnimation(
        parent: _flameController,
        curve: Curves.easeInOut,
      ),
    );

    // ============================================================
    // TEXT ANIMATION
    // ============================================================

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start text slightly after flames appear.

    Future.delayed(
      const Duration(milliseconds: 700),
          () {
        if (mounted) {
          _textController.forward();
        }
      },
    );

    // ============================================================
    // SPLASH DURATION
    // ============================================================

    _navigationTimer = Timer(
      const Duration(seconds: 5),
      _goToNextScreen,
    );
  }

  // ================================================================
  // FULL SCREEN
  // ================================================================

  void _setFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  // ================================================================
  // NAVIGATION
  // ================================================================

  void _goToNextScreen() {
    if (!mounted) return;

    // Restore normal system UI.

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const ScanScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    _navigationTimer?.cancel();

    _flameController.dispose();
    _textController.dispose();

    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ======================================================
            // BACKGROUND
            // ======================================================

            const _Background(),

            // ======================================================
            // LARGE BACKGROUND FLAMES
            // ======================================================

            _BackgroundFlames(
              animation: _flameController,
            ),

            // ======================================================
            // MAIN CENTER CONTENT
            // ======================================================

            SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // =================================================
                    // MAIN FLAMES
                    // NO logo.png HERE
                    // =================================================

                    _MainFlames(
                      opacity: _flameOpacity,
                      scale: _flameScale,
                      move: _flameMove,
                    ),

                    const SizedBox(height: 28),

                    // =================================================
                    // BRAND TEXT
                    // =================================================

                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: const _BrandText(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ======================================================
            // TOP BRAND
            // ======================================================

            Positioned(
              top: 35,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _textOpacity,
                child: const _TopBrand(),
              ),
            ),

            // ======================================================
            // FOOTER
            // ======================================================

            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: FadeTransition(
                opacity: _textOpacity,
                child: const _Footer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BACKGROUND
// ====================================================================

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.15,
          colors: [
            Color(0xFF17100A),
            Color(0xFF0A0806),
            Color(0xFF050505),
          ],
          stops: [
            0.0,
            0.48,
            1.0,
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BACKGROUND FLAMES
// ====================================================================
//
// These are extremely subtle.
// The main flames are shown separately in the center.
// ====================================================================

class _BackgroundFlames extends StatelessWidget {
  final Animation<double> animation;

  const _BackgroundFlames({
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final movement =
          Tween<double>(
            begin: -10,
            end: 10,
          ).evaluate(animation);

          final scale =
          Tween<double>(
            begin: 1.0,
            end: 1.08,
          ).evaluate(animation);

          final opacity =
          Tween<double>(
            begin: 0.04,
            end: 0.09,
          ).evaluate(animation);

          return Stack(
            children: [
              Positioned(
                left: -size.width * 0.35,
                right: -size.width * 0.35,
                top: size.height * 0.02 + movement,
                bottom: size.height * 0.02,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Image.asset(
                      'assets/images/flames.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================================
// MAIN FLAMES
// ====================================================================
//
// THIS replaces logo.png.
//
// flames.png is now the main visual identity of the splash screen.
// ====================================================================

class _MainFlames extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> scale;
  final Animation<double> move;

  const _MainFlames({
    required this.opacity,
    required this.scale,
    required this.move,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final flameSize = screenWidth * 0.58;

    return AnimatedBuilder(
      animation: Listenable.merge([
        opacity,
        scale,
        move,
      ]),
      builder: (context, child) {
        return SizedBox(
          width: flameSize,
          height: flameSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ------------------------------------------------------
              // ORANGE GLOW
              // ------------------------------------------------------

              Container(
                width: flameSize * 0.55,
                height: flameSize * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9D42).withOpacity(0.22),
                      blurRadius: 80,
                      spreadRadius: 12,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFB45C).withOpacity(0.12),
                      blurRadius: 120,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),

              // ------------------------------------------------------
              // FLAME IMAGE
              // ------------------------------------------------------

              // Opacity(
              //   opacity: opacity.value,
              //   child: Transform.translate(
              //     offset: Offset(0, move.value),
              //     child: Transform.scale(
              //       scale: scale.value,
              //       child: Image.asset(
              //         'assets/images/flames.png',
              //         width: flameSize,
              //         height: flameSize,
              //         fit: BoxFit.contain,
              //         filterQuality: FilterQuality.high,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }
}

// ====================================================================
// BRAND TEXT
// ====================================================================

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ============================================================
        // GARAM MUG
        // ============================================================

        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Garam ',
                style: TextStyle(
                  color: Color(0xFFFFA044),
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.0,
                ),
              ),
              TextSpan(
                text: 'Mug',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ============================================================
        // DIVIDER
        // ============================================================

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 1,
              color: const Color(0xFFFFA044).withOpacity(0.55),
            ),
            const SizedBox(width: 10),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFFA044),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 1,
              color: const Color(0xFFFFA044).withOpacity(0.55),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ============================================================
        // PRODUCT NAME
        // ============================================================

        const Text(
          'SMART COFFEE MUG',
          style: TextStyle(
            color: Color(0xFFD7D7D7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
          ),
        ),

        const SizedBox(height: 8),

        // ============================================================
        // TAGLINE
        // ============================================================

        const Text(
          'Garam • Hot • Smart',
          style: TextStyle(
            color: Color(0xFF858585),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// TOP BRAND
// ====================================================================

class _TopBrand extends StatelessWidget {
  const _TopBrand();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFFFA044),
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 8),

          const Text(
            'GARAM MUG',
            style: TextStyle(
              color: Color(0xFF8F8F8F),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// FOOTER
// ====================================================================

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'SMART HEAT. PERFECT COFFEE.',
          style: TextStyle(
            color: Color(0xFF777777),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 1,
              color: const Color(0xFF333333),
            ),

            const SizedBox(width: 10),

            const Text(
              'Powered by Sanpra Software Solutions',
              style: TextStyle(
                color: Color(0xFF5E5E5E),
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(width: 10),

            Container(
              width: 32,
              height: 1,
              color: const Color(0xFF333333),
            ),
          ],
        ),
      ],
    );
  }
}