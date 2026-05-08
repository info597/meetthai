import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'widgets/app_logo.dart';

class MatchCelebrationScreen extends StatefulWidget {
  final String otherName;
  final String? myAvatarUrl;
  final String? otherAvatarUrl;
  final VoidCallback? onOpenChat;

  const MatchCelebrationScreen({
    super.key,
    required this.otherName,
    this.myAvatarUrl,
    this.otherAvatarUrl,
    this.onOpenChat,
  });

  @override
  State<MatchCelebrationScreen> createState() =>
      _MatchCelebrationScreenState();
}

class _MatchCelebrationScreenState extends State<MatchCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final AnimationController _fireworkController;
  late final AnimationController _floatingController;
  late final AnimationController _avatarController;
  late final AnimationController _shineController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  final Random _random = Random();
  late final List<_FireworkBurst> _bursts;
  late final List<_FloatingHeart> _floatingHearts;
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    _fireworkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    );

    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.elasticOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _bursts = _buildFireworks();
    _floatingHearts = _buildFloatingHearts();
    _sparkles = _buildSparkles();

    _introController.forward();
    _avatarController.forward();
    _pulseController.repeat(reverse: true);
    _fireworkController.repeat();
    _floatingController.repeat();
    _shineController.repeat();
  }

  List<_FireworkBurst> _buildFireworks() {
    return List.generate(8, (index) {
      return _FireworkBurst(
        center: Offset(
          0.10 + _random.nextDouble() * 0.80,
          0.08 + _random.nextDouble() * 0.44,
        ),
        delay: index * 0.115,
        color: _fireworkColors[index % _fireworkColors.length],
        particles: List.generate(24 + _random.nextInt(12), (particleIndex) {
          final angle = (particleIndex / 36) * pi * 2;
          final speed = 38 + _random.nextDouble() * 66;
          final size = 2.0 + _random.nextDouble() * 4.2;

          return _FireworkParticle(
            angle: angle + (_random.nextDouble() * 0.48),
            speed: speed,
            size: size,
          );
        }),
      );
    });
  }

  List<_FloatingHeart> _buildFloatingHearts() {
    return List.generate(40, (index) {
      return _FloatingHeart(
        x: _random.nextDouble(),
        startY: 0.78 + _random.nextDouble() * 0.36,
        size: 10 + _random.nextDouble() * 24,
        speed: 0.18 + _random.nextDouble() * 0.38,
        delay: _random.nextDouble(),
        opacity: 0.22 + _random.nextDouble() * 0.48,
        rotation: -0.7 + _random.nextDouble() * 1.4,
      );
    });
  }

  List<_Sparkle> _buildSparkles() {
    return List.generate(36, (index) {
      return _Sparkle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 5,
        delay: _random.nextDouble(),
        opacity: 0.18 + _random.nextDouble() * 0.55,
      );
    });
  }

  static const List<Color> _fireworkColors = [
    Color(0xFFFFD54F),
    Color(0xFFFF4081),
    Color(0xFF7C4DFF),
    Color(0xFF40C4FF),
    Color(0xFFFF8A65),
    Color(0xFFFFFFFF),
  ];

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    _fireworkController.dispose();
    _floatingController.dispose();
    _avatarController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _openChat() {
    final callback = widget.onOpenChat;

    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(context).pop();
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF2D75),
            Color(0xFFB5179E),
            Color(0xFF7209B7),
            Color(0xFF240046),
          ],
          stops: [0.0, 0.35, 0.68, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildGlowLayer() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GlowPainter(animationValue: _pulseController.value),
      ),
    );
  }

  Widget _buildFireworkLayer() {
    return AnimatedBuilder(
      animation: _fireworkController,
      builder: (context, _) {
        return CustomPaint(
          painter: _FireworkPainter(
            progress: _fireworkController.value,
            bursts: _bursts,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildFloatingHeartsLayer() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, _) {
        return CustomPaint(
          painter: _FloatingHeartsPainter(
            progress: _floatingController.value,
            hearts: _floatingHearts,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildSparkleLayer() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        return CustomPaint(
          painter: _SparklePainter(
            progress: _shineController.value,
            sparkles: _sparkles,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildAvatar({
    required String? url,
    required bool left,
  }) {
    final rotation = left ? -0.14 : 0.14;

    return AnimatedBuilder(
      animation: Listenable.merge([_avatarController, _pulseController]),
      builder: (context, child) {
        final intro = Curves.easeOutBack.transform(_avatarController.value);
        final pulse = _pulseController.value;

        final dx = left ? (-34 + intro * 34) : (34 - intro * 34);
        final scale = 0.82 + (intro * 0.18) + (pulse * 0.035);

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: 126,
        height: 126,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: left
                ? const [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFC1E3),
                    Color(0xFFFF5FA2),
                  ]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFE0B2),
                    Color(0xFFFF8A65),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 13),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.48),
              blurRadius: 26,
              spreadRadius: 1.5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: ClipOval(
          child: Container(
            color: Colors.white.withValues(alpha: 0.16),
            child: (url != null && url.isNotEmpty)
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.person_rounded,
                        size: 54,
                        color: Color(0xFFE91E63),
                      );
                    },
                  )
                : const Icon(
                    Icons.person_rounded,
                    size: 54,
                    color: Color(0xFFE91E63),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterHeart() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _shineController]),
      builder: (context, child) {
        final pulse = _pulseController.value;
        final shine = _shineController.value;
        final scale = 1.0 + (pulse * 0.18);

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 142,
                height: 142,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.pinkAccent.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16 + pulse * 0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.40 + pulse * 0.20),
                      blurRadius: 44 + pulse * 20,
                      spreadRadius: 8 + pulse * 5,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.24),
                      blurRadius: 62,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: shine * pi * 2,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.00),
                        Colors.white.withValues(alpha: 0.42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 102,
                height: 102,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.pinkAccent,
                      Colors.pink.shade400,
                      const Color(0xFFFF8A65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.50),
                      blurRadius: 24 + pulse * 20,
                      spreadRadius: 3 + pulse * 3,
                    ),
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.58),
                      blurRadius: 42,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.34),
                      blurRadius: 58,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 62,
                ),
              ),
              Positioned(
                right: 18,
                top: 18,
                child: Transform.rotate(
                  angle: -0.25 + pulse * 0.3,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFFFFF3C4).withValues(alpha: 0.92),
                    size: 24 + pulse * 8,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarStage() {
    return Container(
      width: 326,
      height: 204,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _shineController,
                builder: (context, _) {
                  final shine = _shineController.value;

                  return Container(
                    width: 238,
                    height: 124,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment(-1.2 + shine * 2.4, -0.6),
                        end: Alignment(-0.2 + shine * 2.4, 0.6),
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.20),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.10),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: _buildAvatar(
              url: widget.myAvatarUrl,
              left: true,
            ),
          ),
          Positioned(
            right: 0,
            child: _buildAvatar(
              url: widget.otherAvatarUrl,
              left: false,
            ),
          ),
          _buildCenterHeart(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final pulse = _pulseController.value;

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFB300),
                        Colors.pinkAccent,
                        const Color(0xFFFF7043),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withValues(alpha: 0.36 + pulse * 0.14),
                        blurRadius: 22 + pulse * 10,
                        spreadRadius: 2 + pulse * 3,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.20),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text(
                      'Nachricht schreiben',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _close,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    'Weiter swipen',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.82),
                      width: 1.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
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

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        final shine = _shineController.value;

        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.4 + shine * 2.8, 0),
              end: Alignment(-0.2 + shine * 2.8, 0),
              colors: const [
                Color(0xFFFFF3C4),
                Colors.white,
                Color(0xFFFF80AB),
                Color(0xFFFFD54F),
                Colors.white,
              ],
            ).createShader(bounds);
          },
          child: const Text(
            "IT'S A MATCH!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.9,
              height: 1.02,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final name =
        widget.otherName.trim().isEmpty ? 'dein Match' : widget.otherName;

    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: IconButton(
                      onPressed: _close,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: AppLogo(size: 62),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTitle(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Du und $name habt euch gegenseitig geliked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.93),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildAvatarStage(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                  child: Text(
                    'Vielleicht beginnt hier etwas Besonderes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseController,
          _fireworkController,
          _floatingController,
          _shineController,
          _avatarController,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              _buildBackground(),
              _buildGlowLayer(),
              _buildSparkleLayer(),
              _buildFireworkLayer(),
              _buildFloatingHeartsLayer(),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.1, sigmaY: 1.1),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.07),
                  ),
                ),
              ),
              _buildContent(),
            ],
          );
        },
      ),
    );
  }
}

class _FireworkBurst {
  final Offset center;
  final double delay;
  final Color color;
  final List<_FireworkParticle> particles;

  const _FireworkBurst({
    required this.center,
    required this.delay,
    required this.color,
    required this.particles,
  });
}

class _FireworkParticle {
  final double angle;
  final double speed;
  final double size;

  const _FireworkParticle({
    required this.angle,
    required this.speed,
    required this.size,
  });
}

class _FloatingHeart {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double delay;
  final double opacity;
  final double rotation;

  const _FloatingHeart({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.delay,
    required this.opacity,
    required this.rotation,
  });
}

class _Sparkle {
  final double x;
  final double y;
  final double size;
  final double delay;
  final double opacity;

  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.opacity,
  });
}

class _GlowPainter extends CustomPainter {
  final double animationValue;

  const _GlowPainter({
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    final glow1 = Offset(
      size.width * 0.22,
      size.height * (0.22 + animationValue * 0.025),
    );

    final glow2 = Offset(
      size.width * 0.84,
      size.height * (0.58 - animationValue * 0.035),
    );

    final glow3 = Offset(
      size.width * 0.50,
      size.height * (0.82 + animationValue * 0.018),
    );

    paint.shader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.24),
        Colors.white.withValues(alpha: 0.00),
      ],
    ).createShader(
      Rect.fromCircle(
        center: glow1,
        radius: 178,
      ),
    );
    canvas.drawCircle(glow1, 178, paint);

    paint.shader = RadialGradient(
      colors: [
        Colors.pinkAccent.withValues(alpha: 0.30),
        Colors.pinkAccent.withValues(alpha: 0.00),
      ],
    ).createShader(
      Rect.fromCircle(
        center: glow2,
        radius: 224,
      ),
    );
    canvas.drawCircle(glow2, 224, paint);

    paint.shader = RadialGradient(
      colors: [
        Colors.amberAccent.withValues(alpha: 0.16),
        Colors.amberAccent.withValues(alpha: 0.00),
      ],
    ).createShader(
      Rect.fromCircle(
        center: glow3,
        radius: 190,
      ),
    );
    canvas.drawCircle(glow3, 190, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _FireworkPainter extends CustomPainter {
  final double progress;
  final List<_FireworkBurst> bursts;

  const _FireworkPainter({
    required this.progress,
    required this.bursts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final burst in bursts) {
      double local = progress - burst.delay;

      if (local < 0) {
        local += 1.0;
      }

      local = (local * 1.48).clamp(0.0, 1.0);

      final opacity = local < 0.12
          ? local / 0.12
          : (1.0 - ((local - 0.12) / 0.88)).clamp(0.0, 1.0);

      if (opacity <= 0) continue;

      final center = Offset(
        burst.center.dx * size.width,
        burst.center.dy * size.height,
      );

      for (final particle in burst.particles) {
        final distance = particle.speed * Curves.easeOut.transform(local);
        final dx = cos(particle.angle) * distance;
        final dy = sin(particle.angle) * distance + (local * local * 26);

        paint.color = burst.color.withValues(alpha: opacity * 0.96);

        canvas.drawCircle(
          center + Offset(dx, dy),
          particle.size * (1.0 - local * 0.34),
          paint,
        );
      }

      paint
        ..color = Colors.white.withValues(alpha: opacity * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45;

      canvas.drawCircle(
        center,
        18 + (local * 72),
        paint,
      );

      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(covariant _FireworkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.bursts != bursts;
  }
}

class _FloatingHeartsPainter extends CustomPainter {
  final double progress;
  final List<_FloatingHeart> hearts;

  const _FloatingHeartsPainter({
    required this.progress,
    required this.hearts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final heart in hearts) {
      double local = progress + heart.delay;

      if (local > 1) {
        local -= 1;
      }

      final y = (heart.startY - local * heart.speed) * size.height;
      final wobble = sin((local * pi * 2) + heart.delay * 8) * 18;
      final x = heart.x * size.width + wobble;

      final fadeIn = (local / 0.14).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - local) / 0.20).clamp(0.0, 1.0);
      final opacity = heart.opacity * min(fadeIn, fadeOut);

      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(heart.rotation + sin(local * pi * 2) * 0.24);

      textPainter.text = TextSpan(
        text: '♥',
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: heart.size,
          fontWeight: FontWeight.w900,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          -textPainter.width / 2,
          -textPainter.height / 2,
        ),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingHeartsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.hearts != hearts;
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;
  final List<_Sparkle> sparkles;

  const _SparklePainter({
    required this.progress,
    required this.sparkles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final sparkle in sparkles) {
      double local = progress + sparkle.delay;
      if (local > 1) local -= 1;

      final pulse = sin(local * pi * 2).abs();
      final opacity = sparkle.opacity * pulse;
      if (opacity <= 0.02) continue;

      final center = Offset(
        sparkle.x * size.width,
        sparkle.y * size.height,
      );

      paint
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final r = sparkle.size * (0.7 + pulse * 0.8);

      canvas.drawLine(
        center + Offset(-r, 0),
        center + Offset(r, 0),
        paint,
      );
      canvas.drawLine(
        center + Offset(0, -r),
        center + Offset(0, r),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.sparkles != sparkles;
  }
}