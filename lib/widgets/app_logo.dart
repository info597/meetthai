import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppLogo extends StatefulWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 64,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _outerGlow;
  late final Animation<double> _goldGlow;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  late final Animation<double> _auraOpacity;
  late final Animation<double> _auraScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _outerGlow = Tween<double>(
      begin: 0.75,
      end: 1.35,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _goldGlow = Tween<double>(
      begin: 0.80,
      end: 1.25,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scale = Tween<double>(
      begin: 0.985,
      end: 1.025,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rotation = Tween<double>(
      begin: -0.015,
      end: 0.015,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _auraOpacity = Tween<double>(
      begin: 0.45,
      end: 0.90,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _auraScale = Tween<double>(
      begin: 1.00,
      end: 1.035,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final outerGlowValue = _outerGlow.value;
        final goldGlowValue = _goldGlow.value;
        final scaleValue = _scale.value;
        final rotationValue = _rotation.value;
        final auraOpacityValue = _auraOpacity.value;
        final auraScaleValue = _auraScale.value;

        return Transform.rotate(
          angle: rotationValue,
          child: Transform.scale(
            scale: scaleValue,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: auraScaleValue,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD978)
                              .withOpacity(0.55 * auraOpacityValue),
                          width: size * 0.018,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD978)
                                .withOpacity(0.18 * auraOpacityValue),
                            blurRadius: size * 0.10,
                            spreadRadius: size * 0.01,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFE7A8)
                                .withOpacity(0.12 * auraOpacityValue),
                            blurRadius: size * 0.16,
                            spreadRadius: size * 0.02,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D96)
                              .withOpacity(0.36 * outerGlowValue),
                          blurRadius: size * 0.28,
                          spreadRadius: size * 0.04,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF5AB3)
                              .withOpacity(0.28 * outerGlowValue),
                          blurRadius: size * 0.42,
                          spreadRadius: size * 0.07,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF92CB)
                              .withOpacity(0.20 * outerGlowValue),
                          blurRadius: size * 0.58,
                          spreadRadius: size * 0.10,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD36E)
                              .withOpacity(0.14 * outerGlowValue),
                          blurRadius: size * 0.78,
                          spreadRadius: size * 0.13,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: EdgeInsets.all(size * 0.05),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFFFF3D1),
                          width: size * 0.012,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD36E)
                                .withOpacity(0.18 * goldGlowValue),
                            blurRadius: size * 0.08,
                            spreadRadius: size * 0.01,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFE7A8)
                                .withOpacity(0.16 * goldGlowValue),
                            blurRadius: size * 0.14,
                            spreadRadius: size * 0.02,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.85),
                            blurRadius: size * 0.025,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: const [
                                    Color(0xFFFF5FA8),
                                    Color(0xFFFF8A65),
                                    Color(0xFFFFD54F),
                                  ],
                                  stops: [0.0, 0.6, 1.0],
                                  transform:
                                      const GradientRotation(math.pi / 8),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: size * 0.46,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}