import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/chat_service.dart';
import 'services/like_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Map<String, dynamic>? _profile;

  bool _alreadyMatched = false;
  bool _alreadyLiked = false;
  bool _isBlockedPair = false;
  bool _blockedByMe = false;
  String? _existingConversationId;

  AppStrings get _t => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _load();
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

      final results = await Future.wait([
        _supa
            .from('profiles')
            .select('''
              user_id,
              display_name,
              avatar_url,
              city,
              origin_country,
              job,
              bio,
              about_me,
              gender,
              is_online,
              is_gold,
              is_premium,
              birthdate,
              zodiac_sign,
              languages,
              hobbies,
              desired_partner,
              smoking_status,
              ethnicity,
              country,
              province,
              postal_code,
              show_postal_code,
              hair_color,
              eye_color,
              height_cm,
              weight_kg,
              body_type,
              job_category,
              other_job
            ''')
            .eq('user_id', widget.userId)
            .maybeSingle(),
        _supa
            .from('matches')
            .select('conversation_id')
            .or(
              'and(user_a.eq.${me.id},user_b.eq.${widget.userId}),and(user_a.eq.${widget.userId},user_b.eq.${me.id})',
            )
            .maybeSingle(),
        _supa
            .from('likes')
            .select('id')
            .eq('from_user_id', me.id)
            .eq('to_user_id', widget.userId)
            .maybeSingle(),
        _supa
            .from('user_blocks')
            .select('blocker_user_id, blocked_user_id')
            .or(
              'and(blocker_user_id.eq.${me.id},blocked_user_id.eq.${widget.userId}),and(blocker_user_id.eq.${widget.userId},blocked_user_id.eq.${me.id})',
            )
            .maybeSingle(),
      ]);

      final profileRow = results[0] as Map<String, dynamic>?;
      final matchRow = results[1] as Map<String, dynamic>?;
      final likeRow = results[2] as Map<String, dynamic>?;
      final blockRow = results[3] as Map<String, dynamic>?;

      String? conversationId = matchRow?['conversation_id']?.toString();

      if (matchRow != null &&
          (conversationId == null || conversationId.trim().isEmpty)) {
        try {
          conversationId = await ChatService.getOrCreateConversationId(
            widget.userId,
          );
        } catch (_) {}
      }

      final blockedByMe =
          blockRow?['blocker_user_id']?.toString() == me.id &&
              blockRow?['blocked_user_id']?.toString() == widget.userId;

      if (!mounted) return;

      setState(() {
        _profile = profileRow;
        _alreadyMatched = matchRow != null;
        _alreadyLiked = likeRow != null;
        _isBlockedPair = blockRow != null;
        _blockedByMe = blockedByMe;
        _existingConversationId = conversationId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            '${_t.isGerman ? 'Profil konnte nicht geladen werden' : _t.isThai ? 'ไม่สามารถโหลดโปรไฟล์ได้' : 'Profile could not be loaded'}: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleLike({required bool superLike}) async {
    if (_actionLoading || _isBlockedPair) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final result = await LikeService.likeUser(
        targetUserId: widget.userId,
        superLike: superLike,
      );

      if (!mounted) return;

      if (result.matched && result.conversationId != null) {
        setState(() {
          _alreadyMatched = true;
          _alreadyLiked = true;
          _existingConversationId = result.conversationId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t.isGerman
                  ? "It's a Match! 🎉"
                  : _t.isThai
                      ? 'แมตช์แล้ว! 🎉'
                      : "It's a Match! 🎉",
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;

        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'conversationId': result.conversationId,
            'otherUserId': widget.userId,
            'otherDisplayName': _displayName,
            'otherAvatarUrl': _avatarUrl,
          },
        );
        return;
      }

      setState(() {
        _alreadyLiked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            superLike
                ? (_t.isGerman
                    ? 'Super Like gesendet ⭐'
                    : _t.isThai
                        ? 'ส่งซูเปอร์ไลก์แล้ว ⭐'
                        : 'Super Like sent ⭐')
                : (_t.isGerman
                    ? 'Like gesendet ❤️'
                    : _t.isThai
                        ? 'ส่งไลก์แล้ว ❤️'
                        : 'Like sent ❤️'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString();

      if (msg.contains('BLOCKED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t.isGerman
                  ? 'Dieses Profil ist nicht verfügbar.'
                  : _t.isThai
                      ? 'โปรไฟล์นี้ไม่พร้อมใช้งาน'
                      : 'This profile is not available.',
            ),
          ),
        );
      } else if (msg.contains('CANNOT_LIKE_SELF')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t.isGerman
                  ? 'Du kannst dich nicht selbst liken.'
                  : _t.isThai
                      ? 'คุณไม่สามารถไลก์ตัวเองได้'
                      : 'You cannot like yourself.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_t.isGerman ? 'Fehler beim Senden' : _t.isThai ? 'เกิดข้อผิดพลาดในการส่ง' : 'Error sending'}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _openChat() async {
    if (_actionLoading || _isBlockedPair) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final conversationId = _existingConversationId ??
          await ChatService.getOrCreateConversationId(widget.userId);

      if (!mounted) return;

      setState(() {
        _existingConversationId = conversationId;
      });

      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': widget.userId,
          'otherDisplayName': _displayName,
          'otherAvatarUrl': _avatarUrl,
        },
      );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString();

      if (msg.contains('BLOCKED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t.isGerman
                  ? 'Chat ist für dieses Profil nicht verfügbar.'
                  : _t.isThai
                      ? 'ไม่สามารถเปิดแชตสำหรับโปรไฟล์นี้ได้'
                      : 'Chat is not available for this profile.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_t.isGerman ? 'Chat konnte nicht geöffnet werden' : _t.isThai ? 'ไม่สามารถเปิดแชตได้' : 'Chat could not be opened'}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _blockUser() async {
    if (_actionLoading) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              _t.isGerman
                  ? 'Profil blockieren?'
                  : _t.isThai
                      ? 'บล็อกโปรไฟล์นี้หรือไม่?'
                      : 'Block profile?',
            ),
            content: Text(
              _t.isGerman
                  ? 'Wenn du ${_displayName} blockierst, werden Chat, Match, Likes und Unterhaltung dauerhaft entfernt.'
                  : _t.isThai
                      ? 'หากคุณบล็อก ${_displayName} แชต แมตช์ ไลก์ และการสนทนาจะถูกลบอย่างถาวร'
                      : 'If you block ${_displayName}, chat, match, likes and conversation will be permanently removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  _t.isGerman
                      ? 'Blockieren'
                      : _t.isThai
                          ? 'บล็อก'
                          : 'Block',
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      await _supa.rpc(
        'hard_block_user',
        params: {
          'p_blocked_user_id': widget.userId,
        },
      );

      if (!mounted) return;

      setState(() {
        _isBlockedPair = true;
        _blockedByMe = true;
        _alreadyMatched = false;
        _alreadyLiked = false;
        _existingConversationId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.isGerman
                ? '${_displayName} wurde blockiert.'
                : _t.isThai
                    ? 'บล็อก ${_displayName} แล้ว'
                    : '${_displayName} was blocked.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t.isGerman ? 'Blockieren fehlgeschlagen' : _t.isThai ? 'การบล็อกล้มเหลว' : 'Blocking failed'}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _unblockUser() async {
    if (_actionLoading || !_blockedByMe) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              _t.isGerman
                  ? 'Blockierung aufheben?'
                  : _t.isThai
                      ? 'ยกเลิกการบล็อกหรือไม่?'
                      : 'Remove block?',
            ),
            content: Text(
              _t.isGerman
                  ? 'Wenn du ${_displayName} entblockst, kann das Profil wieder sichtbar werden. Gelöschte Chats, Matches und Likes werden aber nicht automatisch wiederhergestellt.'
                  : _t.isThai
                      ? 'หากคุณยกเลิกการบล็อก ${_displayName} โปรไฟล์นี้อาจมองเห็นได้อีกครั้ง แต่แชต แมตช์ และไลก์ที่ถูกลบจะไม่ถูกกู้คืนอัตโนมัติ'
                      : 'If you unblock ${_displayName}, the profile may become visible again. Deleted chats, matches and likes are not automatically restored.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  _t.isGerman
                      ? 'Entblocken'
                      : _t.isThai
                          ? 'ยกเลิกบล็อก'
                          : 'Unblock',
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      await _supa.rpc(
        'unblock_user',
        params: {
          'p_blocked_user_id': widget.userId,
        },
      );

      if (!mounted) return;

      setState(() {
        _isBlockedPair = false;
        _blockedByMe = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.isGerman
                ? '${_displayName} wurde entblockt.'
                : _t.isThai
                    ? 'ยกเลิกบล็อก ${_displayName} แล้ว'
                    : '${_displayName} was unblocked.',
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t.isGerman ? 'Entblocken fehlgeschlagen' : _t.isThai ? 'การยกเลิกบล็อกล้มเหลว' : 'Unblock failed'}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _reportUser() async {
    final me = _supa.auth.currentUser;
    if (me == null || _actionLoading) return;

    String reason = 'Spam';
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setLocalState) {
                return AlertDialog(
                  title: Text(
                    _t.isGerman
                        ? 'Profil melden'
                        : _t.isThai
                            ? 'รายงานโปรไฟล์'
                            : 'Report profile',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: reason,
                          decoration: InputDecoration(
                            labelText: _t.isGerman
                                ? 'Grund'
                                : _t.isThai
                                    ? 'เหตุผล'
                                    : 'Reason',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Spam',
                              child: Text(
                                _t.isGerman
                                    ? 'Spam'
                                    : _t.isThai
                                        ? 'สแปม'
                                        : 'Spam',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Fake Profil',
                              child: Text(
                                _t.isGerman
                                    ? 'Fake Profil'
                                    : _t.isThai
                                        ? 'โปรไฟล์ปลอม'
                                        : 'Fake profile',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Belästigung',
                              child: Text(
                                _t.isGerman
                                    ? 'Belästigung'
                                    : _t.isThai
                                        ? 'คุกคาม'
                                        : 'Harassment',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Unangemessene Inhalte',
                              child: Text(
                                _t.isGerman
                                    ? 'Unangemessene Inhalte'
                                    : _t.isThai
                                        ? 'เนื้อหาไม่เหมาะสม'
                                        : 'Inappropriate content',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Sonstiges',
                              child: Text(
                                _t.isGerman
                                    ? 'Sonstiges'
                                    : _t.isThai
                                        ? 'อื่น ๆ'
                                        : 'Other',
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() {
                              reason = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: detailsController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: _t.isGerman
                                ? 'Details (optional)'
                                : _t.isThai
                                    ? 'รายละเอียด (ไม่บังคับ)'
                                    : 'Details (optional)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(_t.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        _t.isGerman
                            ? 'Melden'
                            : _t.isThai
                                ? 'รายงาน'
                                : 'Report',
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (!confirmed) {
      detailsController.dispose();
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      await _supa.from('user_reports').insert({
        'reporter_user_id': me.id,
        'reported_user_id': widget.userId,
        'reason': reason,
        'details': detailsController.text.trim().isEmpty
            ? null
            : detailsController.text.trim(),
      });

      detailsController.dispose();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t.isGerman
                ? 'Profil wurde gemeldet. Danke.'
                : _t.isThai
                    ? 'รายงานโปรไฟล์แล้ว ขอบคุณ'
                    : 'Profile was reported. Thank you.',
          ),
        ),
      );
    } catch (e) {
      detailsController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t.isGerman ? 'Melden fehlgeschlagen' : _t.isThai ? 'การรายงานล้มเหลว' : 'Reporting failed'}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  String get _displayName {
    final p = _profile;
    if (p == null) return _t.profile;
    final name = (p['display_name'] ?? '').toString().trim();
    return name.isEmpty ? _t.profile : name;
  }

  String? get _avatarUrl {
    final p = _profile;
    if (p == null) return null;
    final avatar = (p['avatar_url'] ?? '').toString().trim();
    return avatar.isEmpty ? null : avatar;
  }

  String? _publicLocation(Map<String, dynamic> p) {
    final province = (p['province'] ?? '').toString().trim();
    final postalCode = (p['postal_code'] ?? '').toString().trim();
    final showPostalCode = p['show_postal_code'] == true;
    final city = (p['city'] ?? '').toString().trim();
    final country = (p['country'] ?? '').toString().trim();

    final parts = <String>[];

    if (province.isNotEmpty) {
      if (showPostalCode && postalCode.isNotEmpty) {
        parts.add('$province $postalCode');
      } else {
        parts.add(province);
      }
    } else if (city.isNotEmpty) {
      parts.add(city);
    }

    if (country.isNotEmpty) {
      parts.add(country);
    }

    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String? _buildJobText(Map<String, dynamic> p) {
    final category = (p['job_category'] ?? '').toString().trim();
    final otherJob = (p['other_job'] ?? '').toString().trim();
    final job = (p['job'] ?? '').toString().trim();

    final parts = <String>[];

    if (category.isNotEmpty) {
      parts.add(category);
    }

    if (category == 'Sonstiges' && otherJob.isNotEmpty) {
      parts.add(otherJob);
    }

    if (job.isNotEmpty && !parts.contains(job)) {
      parts.add(job);
    }

    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String? _buildLanguagesText(Map<String, dynamic> p) {
    final raw = p['languages'];
    if (raw is! List) return null;

    final values = raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (values.isEmpty) return null;
    return values.join(', ');
  }

  String? _buildHobbiesText(Map<String, dynamic> p) {
    final raw = p['hobbies'];

    if (raw is List) {
      final values = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (values.isEmpty) return null;
      return values.join(', ');
    }

    final fallback = (raw ?? '').toString().trim();
    if (fallback.isEmpty) return null;
    return fallback;
  }

  String? _buildAgeText(Map<String, dynamic> p) {
    final birthRaw = p['birthdate']?.toString();
    if (birthRaw == null || birthRaw.trim().isEmpty) return null;

    final birthdate = DateTime.tryParse(birthRaw);
    if (birthdate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthdate.year;

    final hadBirthday = (now.month > birthdate.month) ||
        (now.month == birthdate.month && now.day >= birthdate.day);

    if (!hadBirthday) {
      age--;
    }

    return age > 0
        ? _t.isGerman
            ? '$age Jahre'
            : _t.isThai
                ? '$age ปี'
                : '$age years'
        : null;
  }

  String _aboutText(Map<String, dynamic> p) {
    final aboutMe = (p['about_me'] ?? '').toString().trim();
    final bio = (p['bio'] ?? '').toString().trim();
    if (aboutMe.isNotEmpty) return aboutMe;
    return bio;
  }

  String? _partnerLabel(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'male':
        return _t.isGerman
            ? 'Männlich'
            : _t.isThai
                ? 'ชาย'
                : 'Male';
      case 'female':
        return _t.isGerman
            ? 'Weiblich'
            : _t.isThai
                ? 'หญิง'
                : 'Female';
      case 'transgender':
        return _t.isGerman
            ? 'Transgender'
            : _t.isThai
                ? 'ทรานส์เจนเดอร์'
                : 'Transgender';
      default:
        final text = raw?.trim() ?? '';
        return text.isEmpty ? null : text;
    }
  }

  Widget _buildTopAvatar(Map<String, dynamic> p) {
    final avatar = (p['avatar_url'] ?? '').toString().trim();

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 58,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person, size: 48) : null,
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: p['is_online'] == true ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanChips(Map<String, dynamic> p) {
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          Chip(
            label: Text(
              p['is_online'] == true
                  ? (_t.isGerman
                      ? 'Online'
                      : _t.isThai
                          ? 'ออนไลน์'
                          : 'Online')
                  : (_t.isGerman
                      ? 'Offline'
                      : _t.isThai
                          ? 'ออฟไลน์'
                          : 'Offline'),
            ),
          ),
          if (p['is_gold'] == true) const Chip(label: Text('GOLD')),
          if (p['is_gold'] != true && p['is_premium'] == true)
            const Chip(label: Text('PREMIUM')),
          if (_alreadyMatched)
            Chip(
              label: Text(
                _t.isGerman
                    ? 'MATCH'
                    : _t.isThai
                        ? 'แมตช์'
                        : 'MATCH',
              ),
            ),
          if (!_alreadyMatched && _alreadyLiked)
            Chip(
              label: Text(
                _t.isGerman
                    ? 'Geliked'
                    : _t.isThai
                        ? 'กดไลก์แล้ว'
                        : 'Liked',
              ),
            ),
          if (_isBlockedPair)
            Chip(
              label: Text(
                _t.isGerman
                    ? 'Blockiert'
                    : _t.isThai
                        ? 'ถูกบล็อก'
                        : 'Blocked',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBox() {
    final description = _isBlockedPair
        ? (_blockedByMe
            ? (_t.isGerman
                ? 'Du hast dieses Profil blockiert. Du kannst die Blockierung wieder aufheben.'
                : _t.isThai
                    ? 'คุณได้บล็อกโปรไฟล์นี้ไว้ คุณสามารถยกเลิกการบล็อกได้'
                    : 'You blocked this profile. You can remove the block.')
            : (_t.isGerman
                ? 'Dieses Profil ist blockiert. Aktionen sind deaktiviert.'
                : _t.isThai
                    ? 'โปรไฟล์นี้ถูกบล็อกอยู่ การกระทำต่าง ๆ ถูกปิดใช้งาน'
                    : 'This profile is blocked. Actions are disabled.'))
        : _alreadyMatched
            ? (_t.isGerman
                ? 'Ihr habt bereits ein Match — öffne direkt den Chat.'
                : _t.isThai
                    ? 'คุณแมตช์กันแล้ว — เปิดแชตได้เลย'
                    : 'You already matched — open the chat directly.')
            : _alreadyLiked
                ? (_t.isGerman
                    ? 'Du hast dieses Profil bereits geliked.'
                    : _t.isThai
                        ? 'คุณได้ไลก์โปรไฟล์นี้แล้ว'
                        : 'You already liked this profile.')
                : (_t.isGerman
                    ? 'Gefällt dir das Profil? Sende ein Like oder Super Like.'
                    : _t.isThai
                        ? 'ชอบโปรไฟล์นี้ไหม? ส่งไลก์หรือซูเปอร์ไลก์ได้เลย'
                        : 'Do you like this profile? Send a like or Super Like.');

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.pink.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.pink.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            description,
            style: TextStyle(
              color: Colors.black.withOpacity(0.72),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (_alreadyMatched && !_isBlockedPair) ...[
            ElevatedButton.icon(
              onPressed: _actionLoading ? null : _openChat,
              icon: const Icon(Icons.chat_bubble_rounded),
              label: Text(_t.chatOpen),
            ),
          ] else if (!_isBlockedPair) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_actionLoading || _alreadyLiked)
                        ? null
                        : () => _handleLike(superLike: false),
                    icon: const Icon(Icons.favorite_rounded),
                    label: Text(
                      _alreadyLiked
                          ? (_t.isGerman
                              ? 'Bereits geliked'
                              : _t.isThai
                                  ? 'ไลก์แล้ว'
                                  : 'Already liked')
                          : _t.like,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_actionLoading || _alreadyLiked)
                        ? null
                        : () => _handleLike(superLike: true),
                    icon: const Icon(Icons.star_rounded),
                    label: Text(_t.superLike),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_actionLoading || (_isBlockedPair && !_blockedByMe))
                          ? null
                          : (_isBlockedPair ? _unblockUser : _blockUser),
                  icon: Icon(
                    _isBlockedPair
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                  ),
                  label: Text(
                    _isBlockedPair
                        ? (_t.isGerman
                            ? 'Entblocken'
                            : _t.isThai
                                ? 'ยกเลิกบล็อก'
                                : 'Unblock')
                        : (_t.isGerman
                            ? 'Blockieren'
                            : _t.isThai
                                ? 'บล็อก'
                                : 'Block'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _reportUser,
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(
                    _t.isGerman
                        ? 'Melden'
                        : _t.isThai
                            ? 'รายงาน'
                            : 'Report',
                  ),
                ),
              ),
            ],
          ),
          if (_actionLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t.profile),
        actions: [
          IconButton(
            tooltip: _t.home,
            icon: const Icon(Icons.home_rounded),
            onPressed: _goHome,
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _t.refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : p == null
                  ? Center(
                      child: Text(
                        _t.isGerman
                            ? 'Profil nicht gefunden.'
                            : _t.isThai
                                ? 'ไม่พบโปรไฟล์'
                                : 'Profile not found.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildTopAvatar(p),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPlanChips(p),
                        _buildActionBox(),
                        _ProfileInfoRow(
                          label: _t.isGerman
                              ? 'Standort'
                              : _t.isThai
                                  ? 'ที่อยู่'
                                  : 'Location',
                          value: _publicLocation(p),
                        ),
                        _ProfileInfoRow(
                          label: _t.age,
                          value: _buildAgeText(p),
                        ),
                        _ProfileInfoRow(
                          label: _t.zodiacSign,
                          value: p['zodiac_sign']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.job,
                          value: _buildJobText(p),
                        ),
                        _ProfileInfoRow(
                          label: _t.gender,
                          value: p['gender']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.isGerman
                              ? 'Herkunft'
                              : _t.isThai
                                  ? 'เชื้อชาติ'
                                  : 'Ethnicity',
                          value: p['ethnicity']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.originCountry,
                          value: p['origin_country']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.languages,
                          value: _buildLanguagesText(p),
                          multiline: true,
                        ),
                        _ProfileInfoRow(
                          label: _t.hobbies,
                          value: _buildHobbiesText(p),
                          multiline: true,
                        ),
                        _ProfileInfoRow(
                          label: _t.desiredPartner,
                          value: _partnerLabel(p['desired_partner']?.toString()),
                        ),
                        _ProfileInfoRow(
                          label: _t.smokingStatus,
                          value: p['smoking_status']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.hairColor,
                          value: p['hair_color']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.eyeColor,
                          value: p['eye_color']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.height,
                          value:
                              p['height_cm'] != null ? '${p['height_cm']} cm' : null,
                        ),
                        _ProfileInfoRow(
                          label: _t.weight,
                          value:
                              p['weight_kg'] != null ? '${p['weight_kg']} kg' : null,
                        ),
                        _ProfileInfoRow(
                          label: _t.bodyType,
                          value: p['body_type']?.toString(),
                        ),
                        _ProfileInfoRow(
                          label: _t.aboutMe,
                          value: _aboutText(p),
                          multiline: true,
                        ),
                      ],
                    ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool multiline;

  const _ProfileInfoRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: multiline
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}