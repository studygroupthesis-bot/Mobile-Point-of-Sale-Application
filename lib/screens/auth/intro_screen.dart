import 'dart:async';
import 'package:flutter/material.dart';

import 'welcome_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;

  late final Animation<double> _nameOpacity;
  late final Animation<Offset> _nameSlide;

  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;

  late final Animation<double> _dot1;
  late final Animation<double> _dot2;
  late final Animation<double> _dot3;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.00, 0.25, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.00, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.06, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.00, 0.40, curve: Curves.easeOut),
      ),
    );

    _nameOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.30, 0.65, curve: Curves.easeIn),
      ),
    );

    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.58, 0.88, curve: Curves.easeIn),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.58, 0.92, curve: Curves.easeOut),
      ),
    );

    _dot1 = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.00, 0.60, curve: Curves.easeInOut),
      ),
    );

    _dot2 = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.20, 0.80, curve: Curves.easeInOut),
      ),
    );

    _dot3 = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.40, 1.00, curve: Curves.easeInOut),
      ),
    );

    _mainController.forward();

    Timer(const Duration(milliseconds: 3800), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 650),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const WelcomeScreen(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB6EFE7),
              Color(0xFFF8F8F8),
              Color(0xFFD6F5EE),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -40,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.95 + (_pulseController.value * 0.12),
                    child: Opacity(
                      opacity: 0.18 + (_pulseController.value * 0.08),
                      child: child,
                    ),
                  );
                },
                child: _glowCircle(
                  size: 220,
                  color: const Color(0xFF59D0C3),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              right: -50,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.00 + (_pulseController.value * 0.10),
                    child: Opacity(
                      opacity: 0.16 + (_pulseController.value * 0.06),
                      child: child,
                    ),
                  );
                },
                child: _glowCircle(
                  size: 250,
                  color: const Color(0xFF0A6A73),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _logoOpacity,
                        child: AnimatedBuilder(
                          animation: _mainController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _logoRotation.value,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: child,
                              ),
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: 1.0 + (_pulseController.value * 0.06),
                                    child: Opacity(
                                      opacity: 0.20 + (_pulseController.value * 0.12),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 190,
                                  height: 190,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0x3359D0C3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x6659D0C3),
                                        blurRadius: 40,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Image.asset(
                                    'assets/SoloLogo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _nameOpacity,
                        child: SlideTransition(
                          position: _nameSlide,
                          child: Image.asset(
                            'assets/Name.png',
                            width: 250,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _taglineOpacity,
                        child: SlideTransition(
                          position: _taglineSlide,
                          child: const Text(
                            'Your Point of Speed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              letterSpacing: 0.25,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _animatedDot(_dot1),
                          const SizedBox(width: 8),
                          _animatedDot(_dot2),
                          const SizedBox(width: 8),
                          _animatedDot(_dot3),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedDot(Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF0A6A73),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _glowCircle({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 90,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}