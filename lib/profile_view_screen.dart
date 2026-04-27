import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileViewScreen extends StatefulWidget {
  final String userId;

  const ProfileViewScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _targetProfile;

  // Viewer-Tier
  bool _viewerLoggedIn = false;
  bool _viewerPremium = false;
  bool _viewerGold = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _allowedPhotosCount(int total) {
    if (!_viewerLoggedIn) return total > 0 ? 1 : 0;
    if (_viewerGold) return total;
    if (_viewerPremium) return total >= 5 ? 5 : total;
    return total >= 3 ? 3 : total;
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final viewer = _supa.auth.currentUser;
    _viewerLoggedIn = viewer != null;

    try {
      // Viewer-Tier aus eigenem profiles-Eintrag laden (is_premium/is_gold)
      if (viewer != null) {
        final me = await _supa
            .from('profiles')
            .select('is_premium,is_gold')
            .eq('user_id', viewer.id)
            .maybeSingle();

        _viewerPremium = (me?['is_premium'] ?? false) as bool;
        _viewerGold = (me?['is_gold'] ?? false) as bool;
      } else {
        _viewerPremium = false;
        _viewerGold = false;
      }

      // Zielprofil laden
      final data = await _supa.from('profiles').select('''
        user_id,
        display_name,
        age,
        city,
        state,
        region,
        origin_country,
        living_country,
        gender,
        ethnicity,
        job,
        job_other,
        languages,
        hobbies,
        zodiac_sign,
        about_me,
        avatar_url,
        photos,
        is_online,
        last_seen
      ''').eq('user_id', widget.userId).maybeSingle();

      if (!mounted) return;
      setState(() {
        _targetProfile = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden des Profils: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_targetProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Profil nicht gefunden.')),
      );
    }

    final p = _targetProfile!;
    final displayName = (p['display_name'] ?? 'Profil').toString();
    final age = p['age'];
    final city = (p['city'] ?? '').toString();
    final region = (p['region'] ?? '').toString();
    final state = (p['state'] ?? '').toString();
    final livingCountry = (p['living_country'] ?? '').toString();
    final originCountry = (p['origin_country'] ?? '').toString();
    final avatarUrl = (p['avatar_url'] ?? '').toString();

    final job = (p['job'] ?? '').toString();
    final jobOther = (p['job_other'] ?? '').toString();
    final fullJob = (job == 'Other' && jobOther.trim().isNotEmpty) ? jobOther : job;

    final gender = (p['gender'] ?? '').toString();
    final ethnicity = (p['ethnicity'] ?? '').toString();
    final zodiac = (p['zodiac_sign'] ?? '').toString();
    final about = (p['about_me'] ?? '').toString();

    final langsRaw = p['languages'];
    final hobbiesRaw = p['hobbies'];
    final languages = (langsRaw is List) ? langsRaw.map((e) => e.toString()).toList() : <String>[];
    final hobbies = (hobbiesRaw is List) ? hobbiesRaw.map((e) => e.toString()).toList() : <String>[];

    final photosRaw = p['photos'];
    final photos = (photosRaw is List)
        ? photosRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    // Falls photos leer, nimm avatar als erstes "Foto"
    final effectivePhotos = <String>[
      if (avatarUrl.trim().isNotEmpty) avatarUrl.trim(),
      ...photos.where((u) => u.trim().isNotEmpty && u.trim() != avatarUrl.trim()),
    ];

    final total = effectivePhotos.length;
    final allowed = _allowedPhotosCount(total);

    final locationLine = [
      if (city.trim().isNotEmpty) city.trim(),
      if (region.trim().isNotEmpty) region.trim(),
      if (state.trim().isNotEmpty) state.trim(),
      if (livingCountry.trim().isNotEmpty) livingCountry.trim(),
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: Text(age != null && age.toString().isNotEmpty ? '$displayName, $age' : displayName),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar/Name Header
            Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundImage:
                      avatarUrl.trim().isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.trim().isEmpty
                      ? const Icon(Icons.person, size: 34)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        age != null && age.toString().isNotEmpty ? '$displayName, $age' : displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (locationLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(locationLine),
                      ],
                      if (originCountry.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Herkunft: ${originCountry.trim()}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Fotos + Gating
            Text(
              'Fotos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),

            if (total == 0)
              _infoCard(
                context,
                title: 'Keine Fotos',
                text: 'Dieses Profil hat noch keine Fotos hochgeladen.',
              )
            else
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: total,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final url = effectivePhotos[i];
                    final locked = i >= allowed;

                    if (locked) {
                      return _lockedPhotoCard(context);
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black12,
                            child: const Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // Hinweis / Upsell Text
            if (!_viewerLoggedIn) ...[
              _infoCard(
                context,
                title: 'Mehr sehen?',
                text: 'Registriere dich, um bis zu 3 Bilder zu sehen. Premium: 5, Gold: alle.',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: const Text('Einloggen / Registrieren'),
                ),
              ),
            ] else if (!_viewerPremium && !_viewerGold && total > allowed) ...[
              _infoCard(
                context,
                title: 'Mehr Fotos freischalten',
                text: 'Mit Premium siehst du bis zu 5 Bilder, mit Gold alle Bilder.',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/upgrade'),
                  child: const Text('Upgrade ansehen'),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Chips/Infos
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (gender.trim().isNotEmpty) _chip(context, 'Gender: ${_prettyGender(gender)}'),
                if (ethnicity.trim().isNotEmpty) _chip(context, 'Ethnie: $ethnicity'),
                if (fullJob.trim().isNotEmpty) _chip(context, 'Job: $fullJob'),
                if (zodiac.trim().isNotEmpty) _chip(context, 'Zodiac: $zodiac'),
              ],
            ),

            const SizedBox(height: 18),

            if (languages.isNotEmpty) _section(context, title: 'Sprachen', child: Text(languages.join(', '))),
            if (hobbies.isNotEmpty) _section(context, title: 'Hobbies', child: Text(hobbies.join(', '))),
            _section(
              context,
              title: 'Über mich',
              child: Text(about.trim().isEmpty ? 'Noch nichts eingetragen.' : about.trim()),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyGender(String g) {
    switch (g) {
      case 'female':
        return 'Frau';
      case 'male':
        return 'Mann';
      case 'trans':
        return 'Transgender';
      case 'none':
        return 'Keine Angabe';
      default:
        return g;
    }
  }

  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text),
    );
  }

  Widget _section(BuildContext context, {required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, {required String title, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }

  Widget _lockedPhotoCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: Colors.black12,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_rounded, size: 32),
                SizedBox(height: 6),
                Text('Gesperrt'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
