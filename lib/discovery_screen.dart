import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
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

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _supa = Supabase.instance.client;
  final _subscription = SubscriptionState.instance;

  bool _loading = true;
  bool _liking = false;
  bool _reporting = false;
  String? _error;

  final List<DiscoveryProfile> _profiles = [];
  int _index = 0;

  LikeQuota? _quota;

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

  void _removeCurrent() {
    if (!_hasCurrent) return;

    setState(() {
      _removeCurrentWithoutSetState();
    });
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

  List<String> _reportReasons(AppStrings t) {
    if (t.isGerman) {
      return [
        'Nacktheit oder sexuelle Inhalte',
        'Kontaktdaten im Profil',
        'Fake-Profil',
        'Belästigung oder Spam',
        'Betrug oder verdächtiges Verhalten',
        'Andere',
      ];
    }

    if (t.isThai) {
      return [
        'ภาพเปลือยหรือเนื้อหาทางเพศ',
        'มีข้อมูลติดต่อในโปรไฟล์',
        'โปรไฟล์ปลอม',
        'คุกคามหรือสแปม',
        'หลอกลวงหรือพฤติกรรมน่าสงสัย',
        'อื่น ๆ',
      ];
    }

    return [
      'Nudity or sexual content',
      'Contact details in profile',
      'Fake profile',
      'Harassment or spam',
      'Scam or suspicious behavior',
      'Other',
    ];
  }

  String _reportTitle(AppStrings t) {
    if (t.isGerman) return 'Profil melden';
    if (t.isThai) return 'รายงานโปรไฟล์';
    return 'Report profile';
  }

  String _reportReasonLabel(AppStrings t) {
    if (t.isGerman) return 'Grund';
    if (t.isThai) return 'เหตุผล';
    return 'Reason';
  }

  String _reportDetailsLabel(AppStrings t) {
    if (t.isGerman) return 'Details optional';
    if (t.isThai) return 'รายละเอียดเพิ่มเติม (ไม่บังคับ)';
    return 'Details optional';
  }

  String _reportButtonLabel(AppStrings t) {
    if (t.isGerman) return 'Melden';
    if (t.isThai) return 'รายงาน';
    return 'Report';
  }

  String _reportSuccessMessage(AppStrings t) {
    if (t.isGerman) return 'Danke. Deine Meldung wurde gespeichert.';
    if (t.isThai) return 'ขอบคุณ รายงานของคุณถูกบันทึกแล้ว';
    return 'Thank you. Your report has been saved.';
  }

  String _reportErrorMessage(AppStrings t, Object e) {
    if (t.isGerman) return 'Meldung konnte nicht gesendet werden: $e';
    if (t.isThai) return 'ไม่สามารถส่งรายงานได้: $e';
    return 'Report could not be sent: $e';
  }

  Future<void> _openReportDialog(DiscoveryProfile profile) async {
    if (_reporting) return;

    final me = _supa.auth.currentUser;
    if (me == null) return;

    final t = AppStrings.of(context);
    final reasons = _reportReasons(t);
    String selectedReason = reasons.first;
    final detailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(_reportTitle(t)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _reportReasonLabel(t),
                        border: const OutlineInputBorder(),
                      ),
                      items: reasons
                          .map(
                            (reason) => DropdownMenuItem<String>(
                              value: reason,
                              child: Text(
                                reason,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedReason = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: _reportDetailsLabel(t),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(t.cancel),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(_reportButtonLabel(t)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      detailsCtrl.dispose();
      return;
    }

    setState(() {
      _reporting = true;
    });

    try {
      await _supa.from('reports').insert({
        'reporter_user_id': me.id,
        'reported_user_id': profile.userId,
        'report_type': 'profile',
        'reason': selectedReason,
        'details': detailsCtrl.text.trim().isEmpty
            ? null
            : detailsCtrl.text.trim(),
        'status': 'open',
      });

      if (!mounted) return;

      setState(() {
        _profiles.removeWhere((p) => p.userId == profile.userId);

        if (_profiles.isEmpty) {
          _index = 0;
        } else if (_index >= _profiles.length) {
          _index = _profiles.length - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reportSuccessMessage(t))),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reportErrorMessage(t, e))),
      );
    } finally {
      detailsCtrl.dispose();

      if (mounted) {
        setState(() {
          _reporting = false;
        });
      }
    }
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
    _removeCurrent();
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
    final t = AppStrings.of(context);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const AppLogo(size: 24),
              const SizedBox(width: 8),
              Text(
                t.isGerman
                    ? "It's a Match! 🎉"
                    : t.isThai
                        ? 'แมตช์แล้ว! 🎉'
                        : "It's a Match! 🎉",
              ),
            ],
          ),
          content: Text(t.itsAMatch(otherName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.continueSwiping),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
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
              child: Text(t.chatOpen),
            ),
          ],
        );
      },
    );
  }

  Widget _swipeBg({required bool left}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: left
            ? Colors.red.withOpacity(0.15)
            : Colors.green.withOpacity(0.15),
      ),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Icon(
        left ? Icons.close_rounded : Icons.favorite_rounded,
        size: 44,
        color: left ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _roundActionButton({
    IconData? icon,
    Widget? customIcon,
    required String label,
    required Future<void> Function()? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap == null ? null : () => onTap(),
          radius: 34,
          child: CircleAvatar(
            radius: 28,
            backgroundColor:
                Colors.white.withOpacity(onTap == null ? 0.5 : 0.9),
            child: customIcon ??
                Icon(
                  icon,
                  size: 28,
                  color: onTap == null ? Colors.black26 : AppColors.primary,
                ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.black.withOpacity(onTap == null ? 0.35 : 0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                Colors.orange.withOpacity(0.18),
                Colors.pink.withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.orange.withOpacity(0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.10),
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
                  color: Colors.white.withOpacity(0.84),
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
                        color: Colors.black.withOpacity(0.72),
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
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
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
                  color: Colors.black.withOpacity(0.74),
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
          : Dismissible(
              key: ValueKey(
                'profile_${profile.userId}_${profile.displayName}_$_index',
              ),
              direction:
                  _liking ? DismissDirection.none : DismissDirection.horizontal,
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

                return false;
              },
              background: _swipeBg(left: false),
              secondaryBackground: _swipeBg(left: true),
              child: GestureDetector(
                onTap: () => _openProfile(profile),
                child: _ProfileCard(profile: profile),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    final t = AppStrings.of(context);
    final currentProfile = _currentProfile;

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
          if (_liking || _reporting)
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
            onPressed: _loading || _liking || _reporting ? null : _refreshScreen,
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
          child: Column(
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
                                ? 'Keine Profile gefunden.\n(Alle verfügbaren Profile sind schon geliked, gematched, gemeldet oder blockiert.)'
                                : t.isThai
                                    ? 'ไม่พบโปรไฟล์\n(โปรไฟล์ที่มีอยู่ถูกไลก์ แมตช์ รายงาน หรือบล็อกไปแล้ว)'
                                    : 'No profiles found.\n(All available profiles are already liked, matched, reported, or blocked.)',
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
                        onTap: (_hasCurrent && !_liking && !_reporting)
                            ? _handleNope
                            : null,
                      ),
                      _roundActionButton(
                        icon: Icons.flag_rounded,
                        label: t.isGerman
                            ? 'Melden'
                            : t.isThai
                                ? 'รายงาน'
                                : 'Report',
                        onTap: (_hasCurrent &&
                                !_liking &&
                                !_reporting &&
                                currentProfile != null)
                            ? () => _openReportDialog(currentProfile)
                            : null,
                      ),
                      _roundActionButton(
                        icon: Icons.favorite_rounded,
                        label: t.like,
                        onTap: (_hasCurrent && !_liking && !_reporting)
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
                        onTap: (_hasCurrent && !_liking && !_reporting)
                            ? () => _handleLike(superLike: true)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DiscoveryProfile profile;

  const _ProfileCard({required this.profile});

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
              Image.network(
                img,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackImage(),
              )
            else
              _buildFallbackImage(),
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
                  color: Colors.black.withOpacity(0.45),
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
                      bg: Colors.amber.withOpacity(0.92),
                      fg: Colors.black,
                    )
                  else if (profile.isPremium)
                    _topBadge(
                      text: 'PREMIUM',
                      bg: Colors.pink.withOpacity(0.92),
                      fg: Colors.white,
                    ),
                  if (desiredPartner != null)
                    _topBadge(
                      text: desiredPartner,
                      bg: Colors.white.withOpacity(0.92),
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
                            color: Colors.white.withOpacity(0.92),
                          ),
                    ),
                  if (job.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      job,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
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
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.24),
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
                          color: Colors.white.withOpacity(0.85),
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