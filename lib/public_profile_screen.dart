import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/profile_photos_gallery.dart';

class PublicProfileScreen extends StatefulWidget {
  final String profileUserId;

  const PublicProfileScreen({
    super.key,
    required this.profileUserId,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supa
          .from('profiles')
          .select()
          .eq('user_id', widget.profileUserId)
          .maybeSingle();

      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _profile = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Profil konnte nicht geladen werden.'),
          ),
        ),
      );
    }

    final name = (_profile?['display_name'] ?? '') as String;
    final city = (_profile?['city'] ?? '') as String;
    final living = (_profile?['living_country'] ?? '') as String;
    final origin = (_profile?['origin_country'] ?? '') as String;
    final job = (_profile?['job'] ?? '') as String;
    final about = (_profile?['about_me'] ?? '') as String;
    final avatarUrl = (_profile?['avatar_url'] ?? '') as String;

    final subtitleParts = <String>[
      if (city.trim().isNotEmpty) city.trim(),
      if (living.trim().isNotEmpty) living.trim(),
      if (origin.trim().isNotEmpty) 'Herkunft: ${origin.trim()}',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 34)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Profil' : name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join(' • '),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 6),
                    if (job.trim().isNotEmpty)
                      Text(
                        job.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (about.trim().isNotEmpty) ...[
            Text('Über mich', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(about.trim()),
            const SizedBox(height: 14),
          ],

          // ✅ Galerie mit Limits + Blur/Lock + Vollbild + Upgrade
          ProfilePhotosGallery(profileUserId: widget.profileUserId),
        ],
      ),
    );
  }
}
