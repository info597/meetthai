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

      if (data != null) {
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
          .eq('user_id', widget.profile.userId.toString())
          .maybeSingle();

      if (data != null) {
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
    final displayName =
        profile.displayName.isEmpty ? 'Unbekannt' : profile.displayName;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(displayName),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.08),
        foregroundColor: Colors.white,
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
          top: false,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  const SizedBox(height: 12),
                  _buildPhotoCarousel(context, visiblePhotos, hasMoreHidden),
                  const SizedBox(height: 18),
                  _buildHeroInfoCard(
                    context: context,
                    profile: profile,
                    displayName: displayName,
                    locationText: locationText,
                    jobText: jobText,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'Über mich',
                    child: Text(
                      (_aboutMe == null || _aboutMe!.trim().isEmpty)
                          ? 'Noch keine Beschreibung vorhanden.'
                          : _aboutMe!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: Colors.black87,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    context: context,
                    icon: Icons.interests_rounded,
                    title: 'Hobbies',
                    child: _hobbies.isEmpty
                        ? Text(
                            'Noch keine Hobbies angegeben.',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _hobbies
                                .map(
                                  (h) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.14),
                                          AppColors.primaryLight
                                              .withOpacity(0.28),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color:
                                            AppColors.primary.withOpacity(0.18),
                                      ),
                                    ),
                                    child: Text(
                                      h,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 82),
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
      return Container(
        height: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.32),
              Colors.black.withOpacity(0.82),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.person_rounded,
            size: 82,
            color: Colors.white70,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            fit: StackFit.expand,
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
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stack) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 52,
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black45,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  children: List.generate(
                    visiblePhotos.length,
                    (index) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index == visiblePhotos.length - 1 ? 0 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: index == _currentPhotoIndex
                              ? Colors.white
                              : Colors.white.withOpacity(0.34),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 28,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Text(
                    '${_currentPhotoIndex + 1} / ${visiblePhotos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (hasMoreHidden)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.48),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Mehr Fotos mit Premium / Gold sichtbar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
      ),
    );
  }


  Widget _buildHeroInfoCard({
    required BuildContext context,
    required DiscoveryProfile profile,
    required String displayName,
    required String? locationText,
    required String? jobText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _buildOnlineChip(profile),
            ],
          ),
          const SizedBox(height: 10),
          _buildSubscriptionChip(profile),
          if (locationText != null || jobText != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (locationText != null)
                  _detailPill(
                    icon: Icons.location_on_rounded,
                    text: locationText,
                  ),
                if (jobText != null)
                  _detailPill(
                    icon: Icons.work_rounded,
                    text: jobText,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _detailPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black54),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineChip(DiscoveryProfile profile) {
    final active = profile.isOnline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? Colors.greenAccent.withOpacity(0.18)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? Colors.green.withOpacity(0.22)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Online' : 'Offline',
            style: TextStyle(
              color: active ? Colors.green.shade800 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
    Color foreground;

    if (profile.isGold) {
      text = 'Gold';
      icon = Icons.diamond_rounded;
      color = AppColors.accentGold;
      foreground = Colors.black;
    } else {
      text = 'Premium';
      icon = Icons.star_rounded;
      color = AppColors.primary;
      foreground = Colors.white;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: foreground,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
