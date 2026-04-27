import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'profile_edit_screen.dart';
import 'services/plan_service.dart';
import 'services/subscription_state.dart';
import 'upgrade_screen.dart';
import 'widgets/profile_photos_gallery.dart';

class ProfilePreviewScreen extends StatefulWidget {
  const ProfilePreviewScreen({super.key});

  @override
  State<ProfilePreviewScreen> createState() => _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends State<ProfilePreviewScreen> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _profile;

  bool _loadingPlan = true;
  PlanStatus _status = PlanStatus.free;

  AppStrings get _t => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _refreshScreen();
  }

  Future<void> _refreshScreen() async {
    await Future.wait([
      _load(),
      _loadPlan(),
    ]);
  }

  Future<void> _loadPlan() async {
    setState(() => _loadingPlan = true);

    try {
      await SubscriptionState.instance.refresh();

      if (!mounted) return;

      final state = SubscriptionState.instance;
      PlanStatus mapped;

      if (state.isGold) {
        switch (state.billingPeriod) {
          case 'semiannual':
            mapped = PlanStatus.goldSemiannual;
            break;
          case 'yearly':
            mapped = PlanStatus.goldYearly;
            break;
          default:
            mapped = PlanStatus.goldMonthly;
        }
      } else if (state.isPremium) {
        switch (state.billingPeriod) {
          case 'semiannual':
            mapped = PlanStatus.premiumSemiannual;
            break;
          case 'yearly':
            mapped = PlanStatus.premiumYearly;
            break;
          default:
            mapped = PlanStatus.premiumMonthly;
        }
      } else {
        mapped = PlanStatus.free;
      }

      setState(() {
        _status = mapped;
        _loadingPlan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = PlanStatus.free;
        _loadingPlan = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final user = _supa.auth.currentUser;
      if (user == null) {
        setState(() {
          _profile = null;
          _loading = false;
        });
        return;
      }

      final data = await _supa
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _loading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );

    if (!mounted) return;
    await _refreshScreen();
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

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  bool get _isGoldStatus {
    switch (_status) {
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return true;
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
      case PlanStatus.free:
        return false;
    }
  }

  bool get _isPremiumStatus {
    switch (_status) {
      case PlanStatus.premiumMonthly:
      case PlanStatus.premiumSemiannual:
      case PlanStatus.premiumYearly:
      case PlanStatus.goldMonthly:
      case PlanStatus.goldSemiannual:
      case PlanStatus.goldYearly:
        return true;
      case PlanStatus.free:
        return false;
    }
  }

  String get _statusLabel {
    return PlanService.labelFor(_status);
  }

  String get _statusPeriodLabel {
    return PlanService.periodLabelFor(_status);
  }

  String get _statusDescription {
    if (_isGoldStatus) {
      if (_t.isGerman) {
        return 'Gold aktiv: unbegrenzte Likes, alle Likes sichtbar, volle Reichweite.';
      }
      if (_t.isThai) {
        return 'Gold ใช้งานอยู่: ไลก์ไม่จำกัด เห็นไลก์ทั้งหมด และเข้าถึงเต็มรูปแบบ';
      }
      return 'Gold active: unlimited likes, all likes visible, full reach.';
    }

    if (_isPremiumStatus) {
      if (_t.isGerman) {
        return 'Premium aktiv: 25 Likes pro Tag und die ersten 25 Likes sichtbar.';
      }
      if (_t.isThai) {
        return 'Premium ใช้งานอยู่: 25 ไลก์ต่อวัน และเห็น 25 ไลก์แรก';
      }
      return 'Premium active: 25 likes per day and the first 25 likes visible.';
    }

    if (_t.isGerman) {
      return 'Free aktiv: 10 Likes pro Tag und die ersten 10 Likes sichtbar.';
    }
    if (_t.isThai) {
      return 'Free ใช้งานอยู่: 10 ไลก์ต่อวัน และเห็น 10 ไลก์แรก';
    }
    return 'Free active: 10 likes per day and the first 10 likes visible.';
  }

  String get _statusBenefitsText {
    if (_isGoldStatus) {
      if (_t.isGerman) {
        return 'Du kannst unbegrenzt liken und alle eingehenden Likes komplett sehen und beantworten.';
      }
      if (_t.isThai) {
        return 'คุณสามารถกดไลก์ได้ไม่จำกัด และเห็นไลก์ทั้งหมดที่เข้ามาพร้อมตอบกลับได้';
      }
      return 'You can like without limits and see and answer all incoming likes.';
    }

    if (_isPremiumStatus) {
      if (_t.isGerman) {
        return 'Du kannst 25 Likes pro Tag senden und die ersten 25 eingehenden Likes sehen und beantworten.';
      }
      if (_t.isThai) {
        return 'คุณสามารถส่ง 25 ไลก์ต่อวัน และเห็น 25 ไลก์แรกที่เข้ามาพร้อมตอบกลับได้';
      }
      return 'You can send 25 likes per day and see and answer the first 25 incoming likes.';
    }

    if (_t.isGerman) {
      return 'Du kannst 10 Likes pro Tag senden und die ersten 10 eingehenden Likes sehen und beantworten.';
    }
    if (_t.isThai) {
      return 'คุณสามารถส่ง 10 ไลก์ต่อวัน และเห็น 10 ไลก์แรกที่เข้ามาพร้อมตอบกลับได้';
    }
    return 'You can send 10 likes per day and see and answer the first 10 incoming likes.';
  }

  String? _publicLocation(Map<String, dynamic> p) {
    final province = (p['province'] ?? '').toString().trim();
    final postalCode = (p['postal_code'] ?? '').toString().trim();
    final showPostalCode = p['show_postal_code'] == true;
    final city = (p['city'] ?? '').toString().trim();
    final country = (p['country'] ?? '').toString().trim();
    final livingCountry = (p['living_country'] ?? '').toString().trim();

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
    } else if (livingCountry.isNotEmpty) {
      parts.add(livingCountry);
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

    if (!hadBirthday) age--;

    if (age <= 0) return null;

    if (_t.isGerman) return '$age Jahre';
    if (_t.isThai) return '$age ปี';
    return '$age years';
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
        final text = (raw ?? '').trim();
        return text.isEmpty ? null : text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t.isGerman
              ? 'Profil Vorschau'
              : _t.isThai
                  ? 'ตัวอย่างโปรไฟล์'
                  : 'Profile preview',
        ),
        actions: [
          IconButton(
            tooltip: _t.home,
            icon: const Icon(Icons.home_rounded),
            onPressed: _goHome,
          ),
          IconButton(
            tooltip: _t.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _refreshScreen,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (user == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_t.loginRequired),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/auth'),
                          child: Text(_t.toLogin),
                        ),
                      ],
                    ),
                  ),
                )
              : _profile == null
                  ? Center(
                      child: Text(
                        _t.isGerman
                            ? 'Profil konnte nicht geladen werden.'
                            : _t.isThai
                                ? 'ไม่สามารถโหลดโปรไฟล์ได้'
                                : 'Profile could not be loaded.',
                      ),
                    )
                  : _buildProfile(context, user.id),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openEditProfile,
        icon: const Icon(Icons.edit_rounded),
        label: Text(
          _t.isGerman
              ? 'Profil bearbeiten'
              : _t.isThai
                  ? 'แก้ไขโปรไฟล์'
                  : 'Edit profile',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, String userId) {
    final p = _profile!;
    final name = (p['display_name'] ?? '').toString().trim();
    final avatarUrl = (p['avatar_url'] ?? '').toString().trim();
    final location = _publicLocation(p);
    final jobText = _buildJobText(p);
    final ageText = _buildAgeText(p);
    final languagesText = _buildLanguagesText(p);
    final hobbiesText = _buildHobbiesText(p);
    final desiredPartnerText = _partnerLabel(p['desired_partner']?.toString());
    final about = _aboutText(p);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEditButton(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child:
                  avatarUrl.isEmpty ? const Icon(Icons.person, size: 32) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? _t.displayName : name,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _loadingPlan
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _LocalPlanStatusChip(
                              label: _statusLabel,
                              periodLabel: _statusPeriodLabel,
                              isGold: _isGoldStatus,
                              isPremium: _isPremiumStatus,
                              onTap: _openUpgrade,
                            ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (location != null && location.isNotEmpty)
                    Text(
                      location,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (jobText != null && jobText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      jobText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _isGoldStatus
                    ? Icons.workspace_premium_rounded
                    : _isPremiumStatus
                        ? Icons.star_rounded
                        : Icons.info_outline_rounded,
                size: 18,
                color: _isGoldStatus
                    ? Colors.amber.shade800
                    : _isPremiumStatus
                        ? Colors.pink.shade700
                        : Colors.black87,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              if (!_isGoldStatus)
                TextButton(
                  onPressed: _openUpgrade,
                  child: Text(
                    _isPremiumStatus
                        ? (_t.isThai ? 'โกลด์' : 'Gold')
                        : (_t.isGerman
                            ? 'Upgrade'
                            : _t.isThai
                                ? 'อัปเกรด'
                                : 'Upgrade'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_isGoldStatus
                    ? Colors.amber
                    : _isPremiumStatus
                        ? Colors.pink
                        : Colors.blueGrey)
                .withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (_isGoldStatus
                      ? Colors.amber
                      : _isPremiumStatus
                          ? Colors.pink
                          : Colors.blueGrey)
                  .withOpacity(0.20),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 18,
                color: _isGoldStatus
                    ? Colors.amber.shade800
                    : _isPremiumStatus
                        ? Colors.pink.shade700
                        : Colors.blueGrey.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusBenefitsText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ProfileInfoRow(
          label: _t.age,
          value: ageText,
        ),
        _ProfileInfoRow(
          label: _t.zodiacSign,
          value: p['zodiac_sign']?.toString(),
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
          value: languagesText,
          multiline: true,
        ),
        _ProfileInfoRow(
          label: _t.hobbies,
          value: hobbiesText,
          multiline: true,
        ),
        _ProfileInfoRow(
          label: _t.desiredPartner,
          value: desiredPartnerText,
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
          value: p['height_cm'] != null ? '${p['height_cm']} cm' : null,
        ),
        _ProfileInfoRow(
          label: _t.weight,
          value: p['weight_kg'] != null ? '${p['weight_kg']} kg' : null,
        ),
        _ProfileInfoRow(
          label: _t.bodyType,
          value: p['body_type']?.toString(),
        ),
        if (about.trim().isNotEmpty) ...[
          Text(_t.aboutMe, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(about),
          const SizedBox(height: 14),
        ],
        ProfilePhotosGallery(profileUserId: userId),
      ],
    );
  }
}

class _LocalPlanStatusChip extends StatelessWidget {
  final String label;
  final String periodLabel;
  final bool isGold;
  final bool isPremium;
  final VoidCallback onTap;

  const _LocalPlanStatusChip({
    required this.label,
    required this.periodLabel,
    required this.isGold,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGold
        ? Colors.amber
        : isPremium
            ? Colors.pink
            : Colors.grey;
    final text = periodLabel.isEmpty ? label : '$label • $periodLabel';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isGold
                ? Colors.amber.shade800
                : isPremium
                    ? Colors.pink.shade700
                    : Colors.black87,
            fontSize: 12,
          ),
        ),
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