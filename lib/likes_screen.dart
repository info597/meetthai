import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/plan_service.dart';
import 'services/subscription_state.dart';
import 'upgrade_screen.dart';
import 'user_profile_screen.dart';
import 'widgets/app_logo.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  final _supa = Supabase.instance.client;
  final _subscription = SubscriptionState.instance;

  static const int _freeVisibleLikesCount = 10;
  static const int _premiumVisibleLikesCount = 25;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _likes = [];

  bool get _isPremium => _subscription.isPremium;
  bool get _isGold => _subscription.isGold;
  bool get _unlockedAll => _isGold;

  bool get _isPromoPremium {
    return !_isGold &&
        _isPremium &&
        _subscription.billingPeriod.trim().toLowerCase() == 'promo';
  }

  AppStrings get _t => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _subscription.addListener(_onSubscriptionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshScreen();
    });
  }

  @override
  void dispose() {
    _subscription.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshScreen() async {
    await _subscription.refresh();
    await _load();
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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = _supa.auth.currentUser;
      if (me == null) {
        throw Exception(_t.loginRequired);
      }

      final likesRes = await _supa.rpc('get_my_likes_preview');
      final deletedUserIds = await _loadDeletedUserIds();

      final allLikes = List<Map<String, dynamic>>.from(likesRes ?? []);
      final filteredLikes = allLikes.where((item) {
        final userId = (item['user_id'] ?? '').toString().trim();
        if (userId.isEmpty) return false;
        return !deletedUserIds.contains(userId);
      }).toList();

      if (!mounted) return;

      setState(() {
        _likes = filteredLikes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            '${_t.isGerman ? 'Likes konnten nicht geladen werden' : _t.isThai ? 'ไม่สามารถโหลดไลก์ได้' : 'Likes could not be loaded'}: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openUpgrade() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );

    if (!mounted) return;

    if (changed == true) {
      await _refreshScreen();
    }
  }

  int get _visibleLikesCount {
    if (_isGold) return _likes.length;
    if (_isPremium) return _premiumVisibleLikesCount;
    return _freeVisibleLikesCount;
  }

  int get _hiddenLikesCount {
    final hidden = _likes.length - _visibleLikesCount;
    return hidden < 0 ? 0 : hidden;
  }

  bool _isVisibleAt(int index) {
    if (_unlockedAll) return true;
    return index < _visibleLikesCount;
  }

  Future<void> _openLikedProfile(Map<String, dynamic> p, int index) async {
    final userId = (p['user_id'] ?? '').toString().trim();
    if (userId.isEmpty) return;

    if (!_isVisibleAt(index)) {
      await _openUpgrade();
      return;
    }

    final blocked = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId),
          ),
        ) ??
        false;

    if (!mounted) return;

    if (blocked == true) {
      setState(() {
        _likes.removeWhere(
          (item) => (item['user_id'] ?? '').toString() == userId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.isGerman
                ? 'Profil wurde aus deinen Likes entfernt.'
                : _t.isThai
                    ? 'โปรไฟล์ถูกลบออกจากไลก์ของคุณแล้ว'
                    : 'Profile was removed from your likes.',
          ),
        ),
      );
    } else {
      await _refreshScreen();
    }
  }

  PlanStatus get _currentPlanStatus {
    if (_subscription.isGold) {
      switch (_subscription.billingPeriod.trim().toLowerCase()) {
        case 'semiannual':
          return PlanStatus.goldSemiannual;
        case 'yearly':
          return PlanStatus.goldYearly;
        default:
          return PlanStatus.goldMonthly;
      }
    }

    if (_subscription.isPremium) {
      switch (_subscription.billingPeriod.trim().toLowerCase()) {
        case 'semiannual':
          return PlanStatus.premiumSemiannual;
        case 'yearly':
          return PlanStatus.premiumYearly;
        case 'promo':
          return PlanStatus.premiumMonthly;
        default:
          return PlanStatus.premiumMonthly;
      }
    }

    return PlanStatus.free;
  }

  String get _planBadgeText {
    if (_isPromoPremium) {
      if (_t.isGerman) return 'PREMIUM • GRATIS';
      if (_t.isThai) return 'PREMIUM • ฟรี';
      return 'PREMIUM • FREE';
    }
    return PlanService.labelFor(_currentPlanStatus);
  }

  String get _heroTitle {
    final count = _likes.length;

    if (_t.isGerman) {
      if (count == 1) return '1 Like wartet auf dich ❤️';
      return '$count Likes warten auf dich ❤️';
    }

    if (_t.isThai) {
      if (count == 1) return 'มี 1 ไลก์รอคุณอยู่ ❤️';
      return 'มี $count ไลก์รอคุณอยู่ ❤️';
    }

    if (count == 1) return '1 like is waiting for you ❤️';
    return '$count likes are waiting for you ❤️';
  }

  String get _heroDescription {
    if (_isGold) {
      if (_t.isGerman) {
        return 'Als Gold User siehst du alle Likes komplett und kannst jedes Profil direkt öffnen und beantworten.';
      }
      if (_t.isThai) {
        return 'ในฐานะผู้ใช้ Gold คุณจะเห็นไลก์ทั้งหมด และสามารถเปิดทุกโปรไฟล์พร้อมตอบกลับได้ทันที';
      }
      return 'As a Gold user, you can see all likes completely and open and answer every profile directly.';
    }

    if (_isPromoPremium) {
      if (_t.isGerman) {
        return 'Mit deinem Gratis Premium kannst du die ersten 25 Likes normal sehen und beantworten. Weitere Likes werden gesperrt angezeigt.';
      }
      if (_t.isThai) {
        return 'ด้วย Premium ฟรีของคุณ คุณสามารถเห็นและตอบกลับ 25 ไลก์แรกได้ตามปกติ ไลก์เพิ่มเติมจะถูกล็อกไว้';
      }
      return 'With your free Premium, you can normally see and answer the first 25 likes. Additional likes stay locked.';
    }

    if (_isPremium) {
      if (_t.isGerman) {
        return 'Als Premium User kannst du die ersten 25 Likes normal sehen und beantworten. Weitere Likes werden gesperrt angezeigt.';
      }
      if (_t.isThai) {
        return 'ในฐานะผู้ใช้ Premium คุณสามารถเห็นและตอบกลับ 25 ไลก์แรกได้ตามปกติ ไลก์เพิ่มเติมจะถูกล็อกไว้';
      }
      return 'As a Premium user, you can normally see and answer the first 25 likes. Additional likes stay locked.';
    }

    if (_t.isGerman) {
      return 'Als Free User kannst du die ersten 10 Likes normal sehen und beantworten. Weitere Likes werden gesperrt angezeigt.';
    }
    if (_t.isThai) {
      return 'ในฐานะผู้ใช้ฟรี คุณสามารถเห็นและตอบกลับ 10 ไลก์แรกได้ตามปกติ ไลก์เพิ่มเติมจะถูกล็อกไว้';
    }
    return 'As a free user, you can normally see and answer the first 10 likes. Additional likes stay locked.';
  }

  String get _heroButtonText {
    if (_isGold) {
      if (_t.isGerman) return 'Gold aktiv';
      if (_t.isThai) return 'Gold ใช้งานอยู่';
      return 'Gold active';
    }

    if (_isPremium) {
      if (_t.isGerman) return 'Mehr als 25 Likes freischalten';
      if (_t.isThai) return 'ปลดล็อกมากกว่า 25 ไลก์';
      return 'Unlock more than 25 likes';
    }

    if (_t.isGerman) return 'Mehr als 10 Likes freischalten';
    if (_t.isThai) return 'ปลดล็อกมากกว่า 10 ไลก์';
    return 'Unlock more than 10 likes';
  }

  String get _stripVisibilityText {
    if (_isGold) {
      if (_t.isGerman) return 'Alle Likes sichtbar';
      if (_t.isThai) return 'เห็นไลก์ทั้งหมด';
      return 'All likes visible';
    }
    if (_isPremium) {
      if (_t.isGerman) return '25 Likes sichtbar';
      if (_t.isThai) return 'เห็น 25 ไลก์';
      return '25 likes visible';
    }
    if (_t.isGerman) return '10 Likes sichtbar';
    if (_t.isThai) return 'เห็น 10 ไลก์';
    return '10 likes visible';
  }

  String get _lockedOverlayTitle {
    if (_isPremium) {
      if (_t.isGerman) return 'Mehr als 25 Likes';
      if (_t.isThai) return 'มากกว่า 25 ไลก์';
      return 'More than 25 likes';
    }

    if (_t.isGerman) return 'Mehr als 10 Likes';
    if (_t.isThai) return 'มากกว่า 10 ไลก์';
    return 'More than 10 likes';
  }

  String get _lockedOverlaySubtitle {
    if (_isPremium) {
      if (_t.isGerman) {
        return 'Upgrade auf Gold und sieh alle Likes ohne Limit.';
      }
      if (_t.isThai) {
        return 'อัปเกรดเป็น Gold และดูไลก์ทั้งหมดได้แบบไม่จำกัด';
      }
      return 'Upgrade to Gold and see all likes without limits.';
    }

    if (_t.isGerman) {
      return 'Upgrade auf Premium und sieh deutlich mehr Likes.';
    }
    if (_t.isThai) {
      return 'อัปเกรดเป็น Premium และดูไลก์ได้มากขึ้นอย่างชัดเจน';
    }
    return 'Upgrade to Premium and see significantly more likes.';
  }

  Widget _buildTopPromoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isGold
              ? [
                  Colors.amber.withOpacity(0.20),
                  Colors.orange.withOpacity(0.10),
                ]
              : _isPremium
                  ? [
                      Colors.pink.withOpacity(0.18),
                      Colors.deepPurple.withOpacity(0.10),
                    ]
                  : [
                      Colors.pink.withOpacity(0.16),
                      Colors.redAccent.withOpacity(0.08),
                    ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.pink.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.80),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: AppLogo(size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _heroTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildMiniPlanBadge(_planBadgeText),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _heroDescription,
            style: TextStyle(
              color: Colors.black.withOpacity(0.76),
              height: 1.35,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGold ? null : _openUpgrade,
              icon: Icon(
                _isGold
                    ? Icons.workspace_premium_rounded
                    : Icons.auto_awesome_rounded,
              ),
              label: Text(_heroButtonText),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlanBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          color: Colors.black.withOpacity(0.78),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildFeatureStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _featureChip(
            icon: Icons.visibility_rounded,
            text: _stripVisibilityText,
          ),
          _featureChip(
            icon: Icons.favorite_rounded,
            text: _t.isGerman
                ? 'Likes beantworten'
                : _t.isThai
                    ? 'ตอบกลับไลก์'
                    : 'Answer likes',
          ),
          _featureChip(
            icon: Icons.chat_bubble_rounded,
            text: _t.isGerman
                ? 'Mehr Matches'
                : _t.isThai
                    ? 'แมตช์มากขึ้น'
                    : 'More matches',
          ),
        ],
      ),
    );
  }

  Widget _featureChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.pink),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.black.withOpacity(0.76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibleBadge() {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _t.visible,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLockOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.14),
                  Colors.black.withOpacity(0.60),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.94, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 28,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _lockedOverlayTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _lockedOverlaySubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _openUpgrade,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(_t.unlockNow),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikeCard(Map<String, dynamic> p, int index) {
    final avatar = (p['avatar_url'] ?? '').toString().trim();
    final name = (p['display_name'] ?? 'User').toString().trim();

    final visible = _isVisibleAt(index);
    final visibleName = name.isEmpty
        ? (_t.isGerman
            ? 'User'
            : _t.isThai
                ? 'ผู้ใช้'
                : 'User')
        : name;

    return GestureDetector(
      onTap: () => _openLikedProfile(p, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (avatar.isNotEmpty)
              Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackCardBackground(),
              )
            else
              _buildFallbackCardBackground(),
            const Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                    ],
                  ),
                ),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                ),
              ),
            ),
            if (visible) _buildVisibleBadge(),
            if (!visible) _buildPremiumLockOverlay(),
            if (visible)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.90),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _t.isGerman
                            ? 'Öffnen'
                            : _t.isThai
                                ? 'เปิด'
                                : 'Open',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.46),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Colors.pinkAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visible
                            ? visibleName
                            : (_t.isGerman
                                ? 'Jemand mag dich'
                                : _t.isThai
                                    ? 'มีคนชอบคุณ'
                                    : 'Someone likes you'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCardBackground() {
    return Container(
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(
          Icons.person,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomUpgradeBar() {
    if (_isGold || _likes.isEmpty) return const SizedBox.shrink();

    final text = _hiddenLikesCount > 0
        ? (_t.isGerman
            ? '$_hiddenLikesCount Likes sind noch gesperrt'
            : _t.isThai
                ? 'ยังมี $_hiddenLikesCount ไลก์ที่ถูกล็อกอยู่'
                : '$_hiddenLikesCount likes are still locked')
        : (_isPremium
            ? (_t.isGerman
                ? 'Mehr als 25 Likes mit Gold freischalten'
                : _t.isThai
                    ? 'ปลดล็อกมากกว่า 25 ไลก์ด้วย Gold'
                    : 'Unlock more than 25 likes with Gold')
            : (_t.isGerman
                ? 'Mehr Likes mit Premium freischalten'
                : _t.isThai
                    ? 'ปลดล็อกไลก์เพิ่มด้วย Premium'
                    : 'Unlock more likes with Premium'));

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(0.06),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _openUpgrade,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _t.isGerman
                    ? 'Freischalten'
                    : _t.isThai
                        ? 'ปลดล็อก'
                        : 'Unlock',
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  size: 54,
                  color: Colors.pink,
                ),
                const SizedBox(height: 12),
                Text(
                  _t.isGerman
                      ? 'Noch keine Likes erhalten.'
                      : _t.isThai
                          ? 'ยังไม่ได้รับไลก์'
                          : 'No likes received yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t.isGerman
                      ? 'Sobald dich jemand liked, erscheint das hier.'
                      : _t.isThai
                          ? 'เมื่อมีคนกดไลก์คุณ จะปรากฏที่นี่'
                          : 'As soon as someone likes you, it will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.64),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_likes.isEmpty) {
      return _buildEmptyState();
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildTopPromoCard()),
        SliverToBoxAdapter(child: _buildFeatureStrip()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final p = _likes[i];
                return _buildLikeCard(p, i);
              },
              childCount: _likes.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: bottomInset + 92),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t.likes),
        actions: [
          IconButton(
            onPressed: _refreshScreen,
            icon: const Icon(Icons.refresh),
            tooltip: _t.refresh,
          ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: _buildBottomUpgradeBar(),
    );
  }
}