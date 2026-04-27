import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'services/discovery_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  final DiscoveryProfile profile;
  /// Alle Fotos dieses Profils (z.B. aus Supabase Storage).
  /// Aktuell kommt hier meist nur 1 Bild an, aber die Logik ist für mehrere vorbereitet.
  final List<String> photoUrls;

  const ProfileDetailScreen({
    super.key,
    required this.profile,
    required this.photoUrls,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _supa = Supabase.instance.client;

  bool _isLoading = false;

  // Daten aus profiles (volle Details)
  String? _aboutMe;
  List<String> _hobbies = [];

  // Sichtbare Foto-Anzahl, abhängig vom BETRACHTER (nicht vom Profil!)
  int _maxPhotos = 1;

  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadViewerTier();
      await _loadProfileDetails();
    } catch (_) {
      // Fehler werden unten per SnackBar angezeigt, wenn nötig
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Ermittelt, wie viele Fotos der aktuelle BETRACHTER sehen darf:
  /// - nicht eingeloggt: 1
  /// - logged in free: 3
  /// - Premium: 5
  /// - Gold: alle
  Future<void> _loadViewerTier() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      // Gast → nur 1 Foto
      _maxPhotos = 1;
      return;
    }

    try {
      final data = await _supa
          .from('profiles')
          .select('is_premium, is_gold')
          .eq('user_id', user.id)
          .maybeSingle();

      bool isPremium = false;
      bool isGold = false;

      if (data != null && data is Map<String, dynamic>) {
        isPremium = (data['is_premium'] ?? false) as bool;
        isGold = (data['is_gold'] ?? false) as bool;
      }

      if (isGold) {
        _maxPhotos = widget.photoUrls.length;
      } else if (isPremium) {
        _maxPhotos = 5;
      } else {
        _maxPhotos = 3;
      }

      // Sicherheit: niemals mehr als vorhandene Bilder
      if (_maxPhotos > widget.photoUrls.length) {
        _maxPhotos = widget.photoUrls.length;
      }
      if (_maxPhotos <= 0) {
        _maxPhotos = 1;
      }
    } catch (e) {
      // Wenn was schiefgeht → defensiv: wie ein normaler Free-User behandeln
      _maxPhotos = widget.photoUrls.length.clamp(1, 3);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Abo-Status nicht laden: $e')),
      );
    }
  }

  /// Lädt zusätzliche Felder aus `profiles` für das angezeigte Profil:
  /// - about_me
  /// - hobbies
  Future<void> _loadProfileDetails() async {
    try {
      final data = await _supa
          .from('profiles')
          .select('about_me, hobbies')
          .eq('user_id', widget.profile.userId)
          .maybeSingle();

      if (data != null && data is Map<String, dynamic>) {
        _aboutMe = (data['about_me'] ?? '') as String;

        final hobbies = data['hobbies'];
        if (hobbies is List) {
          _hobbies = hobbies.cast<String>();
        } else {
          _hobbies = [];
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden des Profils: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = widget.photoUrls.take(_maxPhotos).toList();
    final hasMoreHidden = widget.photoUrls.length > visiblePhotos.length;

    final profile = widget.profile;

    final locationText = _buildLocationText(profile);
    final jobText =
        (profile.job == null || profile.job!.isEmpty) ? null : profile.job;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile.displayName.isEmpty ? 'Profil' : profile.displayName,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.primaryLight,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Fotos
                  _buildPhotoCarousel(context, visiblePhotos, hasMoreHidden),

                  const SizedBox(height: 16),

                  // Name + Online-Status + Abo-Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          profile.displayName.isEmpty
                              ? 'Unbekannt'
                              : profile.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildOnlineChip(profile),
                    ],
                  ),

                  const SizedBox(height: 8),
                  _buildSubscriptionChip(profile),

                  if (locationText != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (jobText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.work_outline_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            jobText,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Über mich
                  Text(
                    'Über mich',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_aboutMe == null || _aboutMe!.trim().isEmpty)
                        ? 'Noch keine Beschreibung vorhanden.'
                        : _aboutMe!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  // Hobbies
                  Text(
                    'Hobbies',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_hobbies.isEmpty)
                    Text(
                      'Noch keine Hobbies angegeben.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _hobbies
                          .map(
                            (h) => Chip(
                              label: Text(h),
                              backgroundColor:
                                  AppColors.primaryLight.withOpacity(0.3),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 32),
                  // Hier könnten später noch Buttons hin:
                  // "Like", "Chat starten" etc., wenn du möchtest.
                ],
              ),

              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _buildLocationText(DiscoveryProfile profile) {
    final city = profile.city;
    final country = profile.originCountry;

    if ((city == null || city.isEmpty) &&
        (country == null || country.isEmpty)) {
      return null;
    }

    if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) {
      return '$city • $country';
    }

    return city != null && city.isNotEmpty ? city : country;
  }

  Widget _buildPhotoCarousel(
    BuildContext context,
    List<String> visiblePhotos,
    bool hasMoreHidden,
  ) {
    if (visiblePhotos.isEmpty) {
      // Fallback – sollte eigentlich nie passieren
      return Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.grey.shade300,
        ),
        child: const Center(
          child: Icon(
            Icons.person_rounded,
            size: 64,
            color: Colors.white70,
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: visiblePhotos.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPhotoIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final url = visiblePhotos[index];

                    final isNetwork =
                        url.startsWith('http://') || url.startsWith('https://');

                    return Container(
                      color: Colors.black,
                      child: isNetwork
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 48,
                                    color: Colors.white70,
                                  ),
                                );
                              },
                            )
                          : Image.asset(
                              url,
                              fit: BoxFit.cover,
                            ),
                    );
                  },
                ),

                // Foto-Zähler oben
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentPhotoIndex + 1} / ${visiblePhotos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Hinweis, dass es mehr Fotos gäbe (Abo-Gating)
                if (hasMoreHidden)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Mehr Fotos mit Premium / Gold sichtbar 🔓',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineChip(DiscoveryProfile profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: profile.isOnline ? Colors.greenAccent : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            profile.isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionChip(DiscoveryProfile profile) {
    if (!profile.isGold && !profile.isPremium) {
      return const SizedBox.shrink();
    }

    String text;
    IconData icon;
    Color color;

    if (profile.isGold) {
      text = 'Gold';
      icon = Icons.diamond_rounded;
      color = AppColors.accentGold;
    } else {
      text = 'Premium';
      icon = Icons.star_rounded;
      color = AppColors.primary;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
