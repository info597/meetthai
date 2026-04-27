import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

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
      final row = await _supa
          .from('profiles')
          .select()
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (!mounted) return;

      if (row == null) {
        setState(() {
          _error = 'Profil nicht gefunden.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _profile = row;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Fehler beim Laden des Profils: $e';
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

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final p = _profile!;
    final name = (p['display_name'] ?? '').toString();
    final city = (p['city'] ?? '').toString();
    final origin = (p['origin_country'] ?? '').toString();
    final job = (p['job'] ?? '').toString();
    final about = (p['about_me'] ?? p['bio'] ?? '').toString();
    final avatar = (p['avatar_url'] ?? '').toString();

    final isOnline = p['is_online'] == true;
    final isPremium = p['is_premium'] == true;
    final isGold = p['is_gold'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Profil' : name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (avatar.isNotEmpty)
              Image.network(
                avatar,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 300,
                color: Colors.grey[300],
                child: const Icon(Icons.person, size: 120),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isGold)
                        const Chip(label: Text('GOLD')),
                      if (!isGold && isPremium)
                        const Chip(label: Text('PREMIUM')),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (city.isNotEmpty || origin.isNotEmpty)
                    Text('$city ${origin.isNotEmpty ? "• $origin" : ""}'),

                  if (job.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(job),
                  ],

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(isOnline ? 'Online' : 'Offline'),
                    ],
                  ),

                  if (about.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Über mich',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(about),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
