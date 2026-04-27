import 'dart:async';
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
  late final AnimationController _pulseController;
  late final AnimationController _appearController;

  final List<_HeartParticle> _hearts = [];
  Timer? _spawnTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _startParticles();
  }

  void _startParticles() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted) return;

      setState(() {
        _hearts.add(_HeartParticle.random());
      });

      // alte entfernen
      _hearts.removeWhere((h) => h.isDead);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _appearController.dispose();
    _spawnTimer?.cancel();
    super.dispose();
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.pink.shade400,
            Colors.deepPurple.shade400,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildHearts() {
    return Stack(
      children: _hearts.map((h) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          left: h.x,
          top: h.y,
          child: Opacity(
            opacity: h.opacity,
            child: Transform.rotate(
              angle: h.rotation,
              child: Icon(
                Icons.favorite,
                color: Colors.white.withOpacity(0.8),
                size: h.size,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCenterPulse() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1 + (_pulseController.value * 0.2);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 50,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar({
    required String? url,
    required Alignment alignment,
    required double rotation,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.pink,
                Colors.orange,
              ],
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: url != null && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.person, size: 40),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.otherName.isEmpty ? 'Match' : widget.otherName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBackground(),
          _buildHearts(),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: Colors.black.withOpacity(0.1)),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _appearController,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const Spacer(),

                  const AppLogo(size: 60),

                  const SizedBox(height: 16),

                  const Text(
                    "IT'S A MATCH!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Du und $name habt euch geliked!',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: 280,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildCenterPulse(),

                        _buildAvatar(
                          url: widget.myAvatarUrl,
                          alignment: const Alignment(-0.9, 0),
                          rotation: -0.3,
                        ),

                        _buildAvatar(
                          url: widget.otherAvatarUrl,
                          alignment: const Alignment(0.9, 0),
                          rotation: 0.3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: widget.onOpenChat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.pink,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: const Text("Chat starten"),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: const Text("Weiter swipen"),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartParticle {
  double x;
  double y;
  double size;
  double opacity;
  double rotation;

  _HeartParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.rotation,
  });

  bool get isDead => opacity <= 0;

  factory _HeartParticle.random() {
    final rand = Random();
    return _HeartParticle(
      x: rand.nextDouble() * 350,
      y: 600 + rand.nextDouble() * 100,
      size: 14 + rand.nextDouble() * 10,
      opacity: 0.6 + rand.nextDouble() * 0.4,
      rotation: rand.nextDouble() * pi,
    );
  }
}