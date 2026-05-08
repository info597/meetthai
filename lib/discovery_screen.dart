import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'match_celebration_screen.dart';
import 'services/discovery_service.dart';
import 'services/like_quota_service.dart';
import 'services/like_service.dart';
import 'services/subscription_state.dart';
import 'theme.dart';
import 'upgrade_screen.dart';
import 'user_profile_screen.dart';
import 'widgets/app_logo.dart';
import 'widgets/like_quota_card.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

enum _SwipeFeedbackType {
  like,
  superLike,
  nope,
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _supa = Supabase.instance.client;
  final _subscription = SubscriptionState.instance;

  bool _loading = true;
  bool _liking = false;
  String? _error;

  final List<DiscoveryProfile> _profiles = [];
  int _index = 0;

  LikeQuota? _quota;

  Timer? _swipeFeedbackTimer;
  Timer? _particleTimer;
  _SwipeFeedbackType? _swipeFeedback;
  double _swipeFeedbackProgress = 0;
  double _dragOffsetX = 0;
  bool _showLikeParticles = false;
  bool _showSuperParticles = false;

  @override
  void initState() {
    super.initState();
    _subscription.addListener(_onSubscriptionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshScreen();
      await DiscoveryService.pingOnline();
    });
  }

  @override
  void dispose() {
    _swipeFeedbackTimer?.cancel();
    _particleTimer?.cancel();
    _subscription.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (_) => false,
    );
  }

  Future<void> _refreshScreen() async {
    await _subscription.refresh();
    await _load();
  }

  Future<void> _openUpgrade() async {
    final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
        ) ??
        false;

    if (!mounted) return;

    if (changed == true) {
      await _refreshScreen();
    }
  }

  Future<Set<String>> _loadBlockedUserIds() async {
    final me = _supa.auth.currentUser;
    if (me == null) return <String>{};

    try {
      final rows = await _supa
          .from('user_blocks')
          .select('blocker_user_id, blocked_user_id')
          .or('blocker_user_id.eq.${me.id},blocked_user_id.eq.${me.id}');

      final blocked = <String>{};

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final blocker = row['blocker_user_id']?.toString();
        final blockedUser = row['blocked_user_id']?.toString();

        if (blocker == me.id && blockedUser != null && blockedUser.isNotEmpty) {
          blocked.add(blockedUser);
        } else if (blockedUser == me.id &&
            blocker != null &&
            blocker.isNotEmpty) {
          blocked.add(blocker);
        }
      }

      return blocked;
    } catch (_) {
      return <String>{};
    }
  }

  Future<Set<String>> _loadDeletedUserIds() async {
    try {
      final rows = await _supa
          .from('profiles')
          .select('user_id')
          .eq('is_deleted', true);

      return (rows as List)
          .map((e) => (e['user_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      try {
        final rows = await _supa
            .from('profiles')
            .select('user_id')
            .not('deleted_at', 'is', null);

        return (rows as List)
            .map((e) => (e['user_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        return <String>{};
      }
    }
  }

  Future<void> _load() async {
    final t = AppStrings.of(context);

    setState(() {
      _loading = true;
      _error = null;
      _profiles.clear();
      _index = 0;
      _swipeFeedback = null;
      _swipeFeedbackProgress = 0;
    });

    try {
      final blockedUserIds = await _loadBlockedUserIds();
      final deletedUserIds = await _loadDeletedUserIds();

      List<DiscoveryProfile> list = [];
      LikeQuota? quota;

      try {
        list = await DiscoveryService.loadDiscoveryProfiles(
          limit: 30,
          excludeAlreadyLiked: true,
        );
      } catch (e) {
        debugPrint('Discovery Fehler: $e');
      }

      try {
        quota = await LikeQuotaService.getMyQuota();
      } catch (e) {
        debugPrint('Quota Fehler: $e');
      }

      final filtered = list
          .where((p) => !blockedUserIds.contains(p.userId))
          .where((p) => !deletedUserIds.contains(p.userId))
          .toList();

      if (!mounted) return;

      setState(() {
        _quota = quota;
        _profiles.addAll(filtered);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = t.isGerman
            ? 'Fehler beim Laden der Profile: $e'
            : t.isThai
                ? 'เกิดข้อผิดพลาดในการโหลดโปรไฟล์: $e'
                : 'Error loading profiles: $e';
        _loading = false;
      });
    }
  }

  Future<void> _reloadQuotaOnly() async {
    try {
      final quota = await LikeQuotaService.getMyQuota();
      if (!mounted) return;
      setState(() {
        _quota = quota;
      });
    } catch (_) {}
  }

  bool get _hasCurrent => _index >= 0 && _index < _profiles.length;

  DiscoveryProfile? get _currentProfile =>
      _hasCurrent ? _profiles[_index] : null;

  DiscoveryProfile? get _nextProfile {
    final nextIndex = _index + 1;
    if (nextIndex < 0 || nextIndex >= _profiles.length) return null;
    return _profiles[nextIndex];
  }

  bool get _canSendLikeByQuota {
    final quota = _quota;
    if (quota == null) return true;
    return quota.hasLikesRemaining;
  }

  bool get _shouldShowAlmostOutBanner {
    final quota = _quota;
    if (quota == null || quota.unlimited) return false;

    final remaining = quota.remainingLikesToday ?? 0;
    return remaining > 0 && remaining <= 2;
  }

  bool get _shouldShowSoftUpgradeHint {
    final quota = _quota;
    if (quota == null || quota.unlimited) return false;

    final remaining = quota.remainingLikesToday ?? 0;
    return remaining > 0 && remaining <= 5;
  }

  String _almostOutTitle(AppStrings t) {
    final quota = _quota;
    final remaining = quota?.remainingLikesToday ?? 0;

    if (remaining == 1) {
      if (t.isGerman) return 'Nur noch 1 Like heute';
      if (t.isThai) return 'เหลืออีก 1 ไลก์วันนี้';
      return 'Only 1 like left today';
    }

    if (t.isGerman) return 'Nur noch $remaining Likes heute';
    if (t.isThai) return 'เหลืออีก $remaining ไลก์วันนี้';
    return 'Only $remaining likes left today';
  }

  String _almostOutSubtitle(AppStrings t) {
    if (_subscription.isGold) {
      if (t.isGerman) return 'Du hast Gold aktiv.';
      if (t.isThai) return 'คุณมี Gold อยู่แล้ว';
      return 'You already have Gold.';
    }
    if (_subscription.isPremium) {
      if (t.isGerman) {
        return 'Danach brauchst du Gold für unbegrenzte Likes.';
      }
      if (t.isThai) {
        return 'หลังจากนั้นคุณต้องใช้ Gold เพื่อไลก์ได้ไม่จำกัด';
      }
      return 'After that, you need Gold for unlimited likes.';
    }

    if (t.isGerman) {
      return 'Danach brauchst du Premium für mehr tägliche Likes.';
    }
    if (t.isThai) {
      return 'หลังจากนั้นคุณต้องใช้ Premium เพื่อเพิ่มจำนวนไลก์ต่อวัน';
    }
    return 'After that, you need Premium for more daily likes.';
  }

  DiscoveryProfile? _removeCurrentWithoutSetState() {
    if (!_hasCurrent) return null;

    final removed = _profiles.removeAt(_index);

    if (_profiles.isEmpty) {
      _index = 0;
    } else if (_index >= _profiles.length) {
      _index = _profiles.length - 1;
    }

    return removed;
  }

  void _reinsertProfileAtCurrentSpot(
    DiscoveryProfile profile,
    int indexBefore,
  ) {
    final insertIndex = indexBefore.clamp(0, _profiles.length);

    setState(() {
      _profiles.insert(insertIndex, profile);
      _index = insertIndex;
    });
  }

  void _clearSwipeFeedback() {
    _swipeFeedbackTimer?.cancel();

    if (_swipeFeedback == null && _swipeFeedbackProgress == 0) return;

    setState(() {
      _swipeFeedback = null;
      _swipeFeedbackProgress = 0;
    });
  }

  void _startSwipeFeedback(_SwipeFeedbackType type) {
    _swipeFeedbackTimer?.cancel();

    setState(() {
      _swipeFeedback = type;
      _swipeFeedbackProgress = 1;
    });

    _swipeFeedbackTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        _swipeFeedback = null;
        _swipeFeedbackProgress = 0;
      });
    });
  }

  void _updateSwipeFeedback(DismissUpdateDetails details) {
    if (_liking) return;

    final progress = details.progress.clamp(0.0, 1.0).toDouble();
    final signedProgress = details.direction == DismissDirection.endToStart
        ? -progress
        : progress;

    if (progress < 0.015) {
      if (_swipeFeedback != null || _swipeFeedbackProgress != 0) {
        setState(() {
          _swipeFeedback = null;
          _swipeFeedbackProgress = 0;
          _dragOffsetX = 0;
          _dragOffsetX = 0;
        });
      }
      return;
    }

    _SwipeFeedbackType? type;

    if (details.direction == DismissDirection.startToEnd) {
      type = _SwipeFeedbackType.like;
    } else if (details.direction == DismissDirection.endToStart) {
      type = _SwipeFeedbackType.nope;
    }

    if (type == null) return;

    final boostedProgress = ((progress - 0.010) / 0.22).clamp(0.0, 1.0);

    if (_swipeFeedback == type &&
        (_swipeFeedbackProgress - boostedProgress).abs() < 0.015) {
      return;
    }

    setState(() {
      _swipeFeedback = type;
      _swipeFeedbackProgress = boostedProgress;
      _dragOffsetX = signedProgress.clamp(-1.0, 1.0).toDouble();
    });
  }

  Future<void> _waitForSwipeFeedback() async {
    await Future.delayed(const Duration(milliseconds: 240));
  }

  void _triggerFloatingParticles({required bool superLike}) {
    _particleTimer?.cancel();

    setState(() {
      _showLikeParticles = !superLike;
      _showSuperParticles = superLike;
    });

    _particleTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _showLikeParticles = false;
        _showSuperParticles = false;
      });
    });
  }

  Future<void> _openProfile(DiscoveryProfile profile) async {
    final blocked = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: profile.userId),
          ),
        ) ??
        false;

    if (!mounted) return;

    if (blocked == true) {
      setState(() {
        _profiles.removeWhere((p) => p.userId == profile.userId);

        if (_profiles.isEmpty) {
          _index = 0;
        } else if (_index >= _profiles.length) {
          _index = _profiles.length - 1;
        }
      });

      final t = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Profil wurde aus Entdecken entfernt.'
                : t.isThai
                    ? 'โปรไฟล์ถูกลบออกจากการค้นหาแล้ว'
                    : 'Profile was removed from discovery.',
          ),
        ),
      );
    } else {
      await _refreshScreen();
    }
  }

  Future<void> _handleNope() async {
    if (!_hasCurrent || _liking) return;

    _startSwipeFeedback(_SwipeFeedbackType.nope);
    await _waitForSwipeFeedback();

    if (!mounted) return;

    setState(() {
      _swipeFeedback = null;
      _swipeFeedbackProgress = 0;
      _dragOffsetX = 0;
      _removeCurrentWithoutSetState();
    });
  }

  void _showQuotaPaywallHint() {
    final isPremium = _subscription.isPremium;
    final t = AppStrings.of(context);

    final content = isPremium
        ? (t.isGerman
            ? 'Dein Premium Tageslimit ist erreicht. Upgrade auf Gold für unbegrenzte Likes.'
            : t.isThai
                ? 'คุณใช้ลิมิต Premium วันนี้ครบแล้ว อัปเกรดเป็น Gold เพื่อไลก์ไม่จำกัด'
                : 'Your Premium daily limit is reached. Upgrade to Gold for unlimited likes.')
        : (t.isGerman
            ? 'Dein Free Tageslimit ist erreicht. Upgrade für mehr Likes pro Tag.'
            : t.isThai
                ? 'คุณใช้ลิมิตฟรีวันนี้ครบแล้ว อัปเกรดเพื่อไลก์ต่อวันมากขึ้น'
                : 'Your free daily limit is reached. Upgrade for more likes per day.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content),
        action: SnackBarAction(
          label: isPremium
              ? (t.isThai ? 'โกลด์' : 'Gold')
              : (t.isGerman
                  ? 'Upgrade'
                  : t.isThai
                      ? 'อัปเกรด'
                      : 'Upgrade'),
          onPressed: _openUpgrade,
        ),
      ),
    );
  }

  void _showLikeError(String msg, {required bool superLike}) {
    final t = AppStrings.of(context);

    if (msg.contains('FREE_LIKE_LIMIT_REACHED:10')) {
      _showQuotaPaywallHint();
      return;
    }

    if (msg.contains('PREMIUM_LIKE_LIMIT_REACHED:25')) {
      _showQuotaPaywallHint();
      return;
    }

    if (msg.contains('FREE_SUPER_LIKE_LIMIT_REACHED:1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Tageslimit erreicht: Free User können 1 Super-Like pro Tag senden.'
                : t.isThai
                    ? 'ถึงลิมิตรายวันแล้ว: ผู้ใช้ฟรีส่งซูเปอร์ไลก์ได้วันละ 1 ครั้ง'
                    : 'Daily limit reached: Free users can send 1 Super Like per day.',
          ),
          action: SnackBarAction(
            label: t.isGerman
                ? 'Upgrade'
                : t.isThai
                    ? 'อัปเกรด'
                    : 'Upgrade',
            onPressed: _openUpgrade,
          ),
        ),
      );
      return;
    }

    if (msg.contains('PREMIUM_SUPER_LIKE_LIMIT_REACHED:5')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Tageslimit erreicht: Premium User können 5 Super-Likes pro Tag senden.'
                : t.isThai
                    ? 'ถึงลิมิตรายวันแล้ว: ผู้ใช้ Premium ส่งซูเปอร์ไลก์ได้วันละ 5 ครั้ง'
                    : 'Daily limit reached: Premium users can send 5 Super Likes per day.',
          ),
          action: SnackBarAction(
            label: t.isThai ? 'โกลด์' : 'Gold',
            onPressed: _openUpgrade,
          ),
        ),
      );
      return;
    }

    if (msg.contains('BLOCKED')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Dieses Profil ist nicht verfügbar.'
                : t.isThai
                    ? 'โปรไฟล์นี้ไม่พร้อมใช้งาน'
                    : 'This profile is not available.',
          ),
        ),
      );
      return;
    }

    if (msg.contains('CANNOT_LIKE_SELF')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Du kannst dich nicht selbst liken.'
                : t.isThai
                    ? 'คุณไม่สามารถไลก์ตัวเองได้'
                    : 'You cannot like yourself.',
          ),
        ),
      );
      return;
    }

    if (msg.contains('NOT_AUTHENTICATED')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Bitte logge dich erneut ein.'
                : t.isThai
                    ? 'กรุณาเข้าสู่ระบบอีกครั้ง'
                    : 'Please log in again.',
          ),
        ),
      );
      return;
    }

    final prefix = superLike
        ? (t.isGerman
            ? 'Fehler beim Super-Like'
            : t.isThai
                ? 'เกิดข้อผิดพลาดกับซูเปอร์ไลก์'
                : 'Error sending Super Like')
        : (t.isGerman
            ? 'Fehler beim Like'
            : t.isThai
                ? 'เกิดข้อผิดพลาดกับการไลก์'
                : 'Error sending like');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$prefix: $msg')),
    );
  }

  Future<void> _handleLike({bool superLike = false}) async {
    final p = _currentProfile;
    if (p == null || _liking) return;

    if (!_canSendLikeByQuota && !superLike) {
      _showQuotaPaywallHint();
      return;
    }

    final indexBefore = _index;
    final t = AppStrings.of(context);

    setState(() {
      _liking = true;
    });

    _startSwipeFeedback(
      superLike ? _SwipeFeedbackType.superLike : _SwipeFeedbackType.like,
    );

    await _waitForSwipeFeedback();

    if (!mounted) return;

    setState(() {
      _swipeFeedback = null;
      _swipeFeedbackProgress = 0;
      _dragOffsetX = 0;
      _removeCurrentWithoutSetState();
    });

    try {
      final result = await LikeService.likeUser(
        targetUserId: p.userId,
        superLike: superLike,
      );

      await Future.wait([
        _reloadQuotaOnly(),
        _subscription.refresh(),
      ]);

      if (!mounted) return;

      _triggerFloatingParticles(superLike: superLike);

      if (result.matched && result.conversationId != null) {
        await _showMatchDialog(
          otherName: p.displayName.isNotEmpty
              ? p.displayName
              : (t.isGerman
                  ? 'Match'
                  : t.isThai
                      ? 'แมตช์'
                      : 'Match'),
          conversationId: result.conversationId!,
          otherUserId: p.userId,
          otherAvatarUrl: p.avatarUrl,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _reinsertProfileAtCurrentSpot(p, indexBefore);

      await Future.wait([
        _reloadQuotaOnly(),
        _subscription.refresh(),
      ]);

      _showLikeError(
        e.toString(),
        superLike: superLike,
      );
    } finally {
      if (mounted) {
        setState(() {
          _liking = false;
          _swipeFeedback = null;
          _swipeFeedbackProgress = 0;
          _dragOffsetX = 0;
        });
      }
    }
  }

  Future<void> _showMatchDialog({
    required String otherName,
    required String conversationId,
    required String otherUserId,
    String? otherAvatarUrl,
  }) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return MatchCelebrationScreen(
            otherName: otherName,
            otherAvatarUrl: otherAvatarUrl,
            onOpenChat: () {
              Navigator.of(routeContext).pop();
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'conversationId': conversationId,
                  'otherUserId': otherUserId,
                  'otherDisplayName': otherName,
                  'otherAvatarUrl': otherAvatarUrl,
                },
              );
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: [
                              Colors.pinkAccent.withValues(alpha: 0.20 * animation.value,),
                              const Color(0xFFFFB300).withValues(alpha: 0.12 * animation.value,),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingParticlesOverlay() {
    final show = _showLikeParticles || _showSuperParticles;
    if (!show) return const SizedBox.shrink();

    final isSuper = _showSuperParticles;
    final color = isSuper ? const Color(0xFFFFB300) : Colors.pinkAccent;
    final icon = isSuper ? Icons.auto_awesome_rounded : Icons.favorite_rounded;

    final particles = List<Widget>.generate(9, (index) {
      final left = 0.18 + (index % 5) * 0.16;
      final delay = index * 0.035;
      final size = isSuper ? 18.0 + (index % 3) * 7 : 16.0 + (index % 4) * 6;
      final drift = (index.isEven ? -1 : 1) * (18.0 + index * 3.0);

      return Positioned.fill(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 620 + index * 35),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final adjusted = (value - delay).clamp(0.0, 1.0);
            final opacity = (1.0 - adjusted).clamp(0.0, 1.0);
            final y = 145.0 * adjusted;
            final x = drift * adjusted;

            return Align(
              alignment: Alignment(
                (left * 2) - 1,
                0.38,
              ),
              child: Transform.translate(
                offset: Offset(x, -y),
                child: Transform.scale(
                  scale: 0.55 + adjusted * 0.75,
                  child: Opacity(
                    opacity: opacity,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Icon(
            icon,
            color: color.withValues(alpha: isSuper ? 0.92 : 0.86),
            size: size,
          ),
        ),
      );
    });

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(children: particles),
      ),
    );
  }

  Widget _swipeBg({required bool left}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: left
            ? Colors.red.withValues(alpha: 0.14)
            : Colors.pinkAccent.withValues(alpha: 0.18),
      ),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Icon(
        left ? Icons.close_rounded : Icons.favorite_rounded,
        size: 44,
        color: left ? Colors.red : Colors.pinkAccent,
      ),
    );
  }

  Widget _buildDecisionOverlay() {
    final type = _swipeFeedback;
    if (type == null) return const SizedBox.shrink();

    final progress = _swipeFeedbackProgress.clamp(0.0, 1.0);
    if (progress <= 0) return const SizedBox.shrink();

    final isNope = type == _SwipeFeedbackType.nope;
    final isSuper = type == _SwipeFeedbackType.superLike;

    final color = isNope
        ? Colors.red
        : isSuper
            ? const Color(0xFFFFB300)
            : Colors.pinkAccent;
    final icon = isNope
        ? Icons.close_rounded
        : isSuper
            ? Icons.auto_awesome_rounded
            : Icons.favorite_rounded;

    final label = isNope
        ? 'NOPE'
        : isSuper
            ? 'SUPER LIKE'
            : 'LIKE';

    final sideAlignment = isNope ? Alignment.centerLeft : Alignment.centerRight;
    final gradientBegin = isNope ? Alignment.centerRight : Alignment.centerLeft;
    final gradientEnd = isNope ? Alignment.centerLeft : Alignment.centerRight;

    final colorOpacity = (0.10 + (progress * 0.55)).clamp(0.0, 0.65);
    final widthFactor = (0.20 + (progress * 0.80)).clamp(0.20, 1.0);
    final badgeOpacity = (progress * 1.65).clamp(0.0, 1.0);
    final badgeScale = (0.78 + (progress * 0.52)).clamp(0.78, 1.30);
    final borderWidth = (2.4 + (progress * 3.2)).clamp(2.4, 5.6);
    final blur = (12.0 + (progress * 36.0)).clamp(12.0, 48.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Align(
                alignment: sideAlignment,
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  heightFactor: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: gradientBegin,
                        end: gradientEnd,
                        colors: [
                          Colors.transparent,
                          color.withValues(alpha: colorOpacity * 0.45),
                          color.withValues(alpha: colorOpacity),
                        ],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (!isNope && !isSuper)
                Center(
                  child: AnimatedOpacity(
                    opacity: (progress * 1.35).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 70),
                    child: Transform.scale(
                      scale: (0.55 + (progress * 0.85)).clamp(0.55, 1.40),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.pinkAccent.withValues(alpha: (0.22 + progress * 0.55).clamp(0.22, 0.77),),
                        size: 190,
                      ),
                    ),
                  ),
                ),
              if (isSuper)
                Center(
                  child: AnimatedOpacity(
                    opacity: (progress * 1.4).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 70),
                    child: Transform.scale(
                      scale: (0.62 + (progress * 0.92)).clamp(0.62, 1.55),
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFFF3C4).withValues(alpha: 0.95),
                              const Color(0xFFFFB300).withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                              blurRadius: 52,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFFF9800),
                            size: 110,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 34,
                left: isNope ? 22 : null,
                right: isNope ? null : 22,
                child: AnimatedOpacity(
                  opacity: badgeOpacity,
                  duration: const Duration(milliseconds: 70),
                  child: Transform.rotate(
                    angle: isNope ? -0.20 : 0.20,
                    child: Transform.scale(
                      scale: badgeScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: color.withValues(alpha: 0.98),
                            width: borderWidth,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.26),
                              blurRadius: blur,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 32,
                              color: color,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              label,
                              style: TextStyle(
                                color: color,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (progress > 0.18)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color.withValues(alpha: 
                          ((progress - 0.18) * 0.60).clamp(0.0, 0.38),
                        ),
                        width: 5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCardWithFeedback(
    DiscoveryProfile profile, {
    double parallaxOffset = 0,
  }) {
    return Stack(
      children: [
        _ProfileCard(
          profile: profile,
          parallaxOffset: parallaxOffset,
        ),
        _buildDecisionOverlay(),
      ],
    );
  }

  Widget _roundActionButton({
    IconData? icon,
    Widget? customIcon,
    required String label,
    required Future<void> Function()? onTap,
  }) {
    final enabled = onTap != null;
    final lowerLabel = label.toLowerCase();
    final isNope = lowerLabel.contains('no') ||
        lowerLabel.contains('nein') ||
        lowerLabel.contains('ไม่');
    final isSuper = lowerLabel.contains('super') ||
        lowerLabel.contains('ซูเปอร์');
    final color = isNope
        ? Colors.redAccent
        : isSuper
            ? const Color(0xFFFFB300)
            : Colors.pinkAccent;
    final size = isSuper ? 62.0 : 68.0;

    var pressed = false;

    return StatefulBuilder(
      builder: (context, setButtonState) {
        Future<void> handleTap() async {
          if (!enabled || onTap == null) return;

          setButtonState(() {
            pressed = true;
          });

          await Future<void>.delayed(const Duration(milliseconds: 90));

          if (context.mounted) {
            setButtonState(() {
              pressed = false;
            });
          }

          await onTap();
        }

        return Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled
                ? (_) {
                    setButtonState(() {
                      pressed = true;
                    });
                  }
                : null,
            onTapCancel: enabled
                ? () {
                    setButtonState(() {
                      pressed = false;
                    });
                  }
                : null,
            onTapUp: enabled
                ? (_) {
                    setButtonState(() {
                      pressed = false;
                    });
                  }
                : null,
            onTap: enabled ? handleTap : null,
            child: AnimatedScale(
              scale: !enabled
                  ? 0.92
                  : pressed
                      ? 0.86
                      : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: enabled ? 0.96 : 0.46),
                  border: Border.all(
                    color: color.withValues(alpha: enabled ? 0.28 : 0.10),
                    width: pressed ? 2.2 : 1.4,
                  ),
                  boxShadow: [
                    if (enabled)
                      BoxShadow(
                        color: color.withValues(alpha: pressed
                              ? (isSuper ? 0.56 : 0.38)
                              : (isSuper ? 0.38 : 0.24),),
                        blurRadius: pressed
                            ? (isSuper ? 42 : 32)
                            : (isSuper ? 30 : 22),
                        spreadRadius: pressed
                            ? (isSuper ? 8 : 5)
                            : (isSuper ? 4 : 1),
                        offset: const Offset(0, 8),
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: pressed ? 0.12 : 0.08),
                      blurRadius: pressed ? 24 : 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: pressed ? 1.18 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutBack,
                    child: customIcon ??
                        Icon(
                          icon,
                          size: isSuper ? 28 : 32,
                          color: enabled ? color : Colors.black26,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlmostOutBanner() {
    final t = AppStrings.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withValues(alpha: 0.18),
                Colors.pink.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _almostOutTitle(t),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _almostOutSubtitle(t),
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openUpgrade,
                child: Text(
                  t.isGerman
                      ? 'Upgrade'
                      : t.isThai
                          ? 'อัปเกรด'
                          : 'Upgrade',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoftUpgradeHint() {
    final quota = _quota;
    final t = AppStrings.of(context);

    if (quota == null || quota.unlimited) {
      return const SizedBox.shrink();
    }

    final isPremium = _subscription.isPremium;
    final remaining = quota.remainingLikesToday ?? 0;

    final text = isPremium
        ? (t.isGerman
            ? 'Noch $remaining Likes heute. Gold gibt dir unbegrenzte Likes.'
            : t.isThai
                ? 'วันนี้เหลืออีก $remaining ไลก์ Gold ให้คุณไลก์ได้ไม่จำกัด'
                : '$remaining likes left today. Gold gives you unlimited likes.')
        : (t.isGerman
            ? 'Noch $remaining Likes heute. Premium erhöht dein Tageslimit deutlich.'
            : t.isThai
                ? 'วันนี้เหลืออีก $remaining ไลก์ Premium จะเพิ่มลิมิตรายวันของคุณ'
                : '$remaining likes left today. Premium increases your daily limit.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: isPremium ? Colors.amber.shade700 : Colors.pink.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.74),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _openUpgrade,
              child: Text(
                isPremium
                    ? (t.isThai ? 'โกลด์' : 'Gold')
                    : (t.isGerman
                        ? 'Upgrade'
                        : t.isThai
                            ? 'อัปเกรด'
                            : 'Upgrade'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCardArea() {
    final profile = _currentProfile;
    final t = AppStrings.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.12, 0.0),
          end: Offset.zero,
        ).animate(animation);

        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
      child: profile == null
          ? Card(
              key: const ValueKey('empty_profile'),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: SizedBox(
                height: 520,
                child: Center(
                  child: Text(t.noProfilesFound),
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                if (_nextProfile != null)
                  Positioned.fill(
                    top: 14 - (_dragOffsetX.abs() * 10),
                    left: 12 - (_dragOffsetX.abs() * 6),
                    right: 12 - (_dragOffsetX.abs() * 6),
                    child: Transform.scale(
                      scale: 0.955 + (_dragOffsetX.abs() * 0.035),
                      child: Opacity(
                        opacity: 0.70 + (_dragOffsetX.abs() * 0.18),
                        child: IgnorePointer(
                          child: _ProfileCard(
                            profile: _nextProfile!,
                            parallaxOffset: -_dragOffsetX * 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                Dismissible(
                  key: ValueKey(
                    'profile_${profile.userId}_${profile.displayName}_$_index',
                  ),
                  direction: _liking
                      ? DismissDirection.none
                      : DismissDirection.horizontal,
                  onUpdate: _updateSwipeFeedback,
                  confirmDismiss: (dir) async {
                    if (_liking) return false;

                    if (dir == DismissDirection.endToStart) {
                      await _handleNope();
                      return false;
                    }

                    if (dir == DismissDirection.startToEnd) {
                      await _handleLike(superLike: false);
                      return false;
                    }

                    _clearSwipeFeedback();
                    return false;
                  },
                  onResize: _clearSwipeFeedback,
                  background: _swipeBg(left: false),
                  secondaryBackground: _swipeBg(left: true),
                  child: GestureDetector(
                    onTap: () => _openProfile(profile),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 90),
                      turns: _dragOffsetX * 0.030,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 90),
                        scale: 1 - (_dragOffsetX.abs() * 0.018),
                        child: _buildProfileCardWithFeedback(
                          profile,
                          parallaxOffset: _dragOffsetX * 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final t = AppStrings.of(context);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.search)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.isGerman
                      ? 'Bitte einloggen, um Profile zu entdecken.'
                      : t.isThai
                          ? 'กรุณาเข้าสู่ระบบเพื่อค้นหาโปรไฟล์'
                          : 'Please log in to discover profiles.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: Text(t.toLogin),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.search),
        actions: [
          IconButton(
            tooltip: t.home,
            icon: const Icon(Icons.home_rounded),
            onPressed: _goHome,
          ),
          if (_liking)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            onPressed: _loading || _liking ? null : _refreshScreen,
            icon: const Icon(Icons.refresh),
            tooltip: t.isGerman
                ? 'Neu laden'
                : t.isThai
                    ? 'โหลดใหม่'
                    : 'Reload',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryLight, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
              const SizedBox(height: 8),
              if (_loading) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 18),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (_error != null) ...[
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _refreshScreen,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              t.isGerman
                                  ? 'Nochmal versuchen'
                                  : t.isThai
                                      ? 'ลองอีกครั้ง'
                                      : 'Try again',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (_profiles.isEmpty) ...[
                if (_quota != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: LikeQuotaCard(
                      quota: _quota!,
                      onUpgradeTap: _openUpgrade,
                    ),
                  ),
                if (_shouldShowAlmostOutBanner) _buildAlmostOutBanner(),
                if (!_shouldShowAlmostOutBanner && _shouldShowSoftUpgradeHint)
                  _buildSoftUpgradeHint(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_search, size: 44),
                          const SizedBox(height: 10),
                          Text(
                            t.isGerman
                                ? 'Keine Profile gefunden.\n(Alle verfügbaren Profile sind schon geliked, gematched oder blockiert.)'
                                : t.isThai
                                    ? 'ไม่พบโปรไฟล์\n(โปรไฟล์ที่มีอยู่ถูกไลก์ แมตช์ หรือบล็อกไปแล้ว)'
                                    : 'No profiles found.\n(All available profiles are already liked, matched, or blocked.)',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _refreshScreen,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              t.isGerman
                                  ? 'Neu laden'
                                  : t.isThai
                                      ? 'โหลดใหม่'
                                      : 'Reload',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                if (_quota != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: LikeQuotaCard(
                      quota: _quota!,
                      onUpgradeTap: _openUpgrade,
                    ),
                  ),
                if (_shouldShowAlmostOutBanner) _buildAlmostOutBanner(),
                if (!_shouldShowAlmostOutBanner && _shouldShowSoftUpgradeHint)
                  _buildSoftUpgradeHint(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _buildAnimatedCardArea(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _roundActionButton(
                        icon: Icons.close_rounded,
                        label: t.nope,
                        onTap: (_hasCurrent && !_liking) ? _handleNope : null,
                      ),
                      _roundActionButton(
                        icon: Icons.favorite_rounded,
                        label: t.like,
                        onTap: (_hasCurrent && !_liking)
                            ? () => _handleLike(superLike: false)
                            : null,
                      ),
                      _roundActionButton(
                        customIcon: const AppLogo(size: 30),
                        label: t.isGerman
                            ? 'Super'
                            : t.isThai
                                ? 'ซูเปอร์'
                                : 'Super',
                        onTap: (_hasCurrent && !_liking)
                            ? () => _handleLike(superLike: true)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
                ],
              ),
              _buildFloatingParticlesOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DiscoveryProfile profile;
  final double parallaxOffset;

  const _ProfileCard({
    required this.profile,
    this.parallaxOffset = 0,
  });

  String? _partnerLabel(String? raw, AppStrings t) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'male':
        return t.isGerman
            ? 'Männlich'
            : t.isThai
                ? 'ชาย'
                : 'Male';
      case 'female':
        return t.isGerman
            ? 'Weiblich'
            : t.isThai
                ? 'หญิง'
                : 'Female';
      case 'transgender':
        return t.isGerman
            ? 'Transgender'
            : t.isThai
                ? 'ทรานส์เจนเดอร์'
                : 'Transgender';
      default:
        final text = (raw ?? '').trim();
        return text.isEmpty ? null : text;
    }
  }

  List<String> _parseCommaList(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return [];

    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _buildOverlayChips() {
    final hobbies = _parseCommaList(profile.hobbies);
    if (hobbies.isNotEmpty) {
      return hobbies.take(2).toList();
    }
    return [];
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(
          Icons.person,
          size: 72,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final title =
        profile.displayName.isNotEmpty ? profile.displayName : t.profile;
    final city = (profile.city ?? '').trim();
    final origin = (profile.originCountry ?? '').trim();
    final job = (profile.job ?? '').trim();
    final desiredPartner = _partnerLabel(profile.desiredPartner, t);
    final overlayChips = _buildOverlayChips();

    final subtitleParts = <String>[
      if (city.isNotEmpty) city,
      if (origin.isNotEmpty) origin,
    ];

    final img = (profile.avatarUrl ?? '').trim();
    final hasNetwork = img.isNotEmpty;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 520,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasNetwork)
              Transform.translate(
                offset: Offset(parallaxOffset, 0),
                child: Transform.scale(
                  scale: 1.06,
                  child: Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackImage(),
                  ),
                ),
              )
            else
              _buildFallbackImage(),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: parallaxOffset.abs() > 1 ? 0.34 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: parallaxOffset >= 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        end: parallaxOffset >= 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: SizedBox(height: 230, width: double.infinity),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: profile.isOnline
                            ? Colors.greenAccent
                            : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      profile.isOnline
                          ? (t.isGerman
                              ? 'Online'
                              : t.isThai
                                  ? 'ออนไลน์'
                                  : 'Online')
                          : (t.isGerman
                              ? 'Offline'
                              : t.isThai
                                  ? 'ออฟไลน์'
                                  : 'Offline'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (profile.isGold)
                    _topBadge(
                      text: 'GOLD',
                      bg: Colors.amber.withValues(alpha: 0.92),
                      fg: Colors.black,
                    )
                  else if (profile.isPremium)
                    _topBadge(
                      text: 'PREMIUM',
                      bg: Colors.pink.withValues(alpha: 0.92),
                      fg: Colors.white,
                    ),
                  if (desiredPartner != null)
                    _topBadge(
                      text: desiredPartner,
                      bg: Colors.white.withValues(alpha: 0.92),
                      fg: Colors.black87,
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                    ),
                  if (job.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      job,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                  if (overlayChips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: overlayChips
                          .map(
                            (item) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    t.isGerman
                        ? 'Tippe auf die Karte, um das Profil anzusehen'
                        : t.isThai
                            ? 'แตะที่การ์ดเพื่อดูโปรไฟล์'
                            : 'Tap the card to view the profile',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBadge({
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}