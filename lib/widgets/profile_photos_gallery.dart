// lib/widgets/profile_photos_gallery.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../services/access_service.dart';
import '../services/profile_photos_service.dart';
import '../upgrade_screen.dart';

class ProfilePhotosGallery extends StatefulWidget {
  final String profileUserId;

  /// Optional: wenn du schon Fotos hast, kannst du sie reinreichen.
  final List<ProfilePhoto>? initialPhotos;

  const ProfilePhotosGallery({
    super.key,
    required this.profileUserId,
    this.initialPhotos,
  });

  @override
  State<ProfilePhotosGallery> createState() => _ProfilePhotosGalleryState();
}

class _ProfilePhotosGalleryState extends State<ProfilePhotosGallery> {
  bool _loading = true;
  List<ProfilePhoto> _photos = [];

  /// Max klare Fotos für den aktuellen Viewer (Free=5, Premium=10, Gold=999)
  int _maxVisible = 1;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    try {
      // Viewer-Limit holen (free/premium/gold)
      _maxVisible = await AccessService.getMaxVisiblePhotosForViewer();

      // Fotos des Profil-Owners laden
      _photos = widget.initialPhotos ??
          await ProfilePhotosService.loadPhotosForUser(widget.profileUserId);
    } catch (_) {
      _photos = [];
      _maxVisible = 1;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openUpgrade() async {
    // Nach Upgrade zurückkommen -> neu bootstrappen (Plan kann sich ändern)
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );

    if (!mounted) return;
    AccessService.invalidateCache(); // wichtig: Plan-Cache reset
    await _bootstrap();
  }

  void _openFullscreen(List<ProfilePhoto> unlockedPhotos, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenGallery(
          photos: unlockedPhotos,
          startIndex: startIndex,
        ),
      ),
    );
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_photos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Noch keine Fotos hochgeladen.'),
      );
    }

    final total = _photos.length;
    final visible = _maxVisible >= 999 ? total : (_maxVisible.clamp(1, total));

    final unlockedPhotos = _photos.take(visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Header: Zähler + Upgrade CTA
        Row(
          children: [
            Text(
              'Fotos ($visible/$total)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (_maxVisible < 999 && visible < total)
              TextButton.icon(
                onPressed: _openUpgrade,
                icon: const Icon(Icons.lock, size: 18),
                label: const Text('Mehr sehen'),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Thumbnails (klickbar)
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: total,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final photo = _photos[index];
              final isUnlocked = index < visible;

              return _Thumb(
                photo: photo,
                unlocked: isUnlocked,
                onTap: () {
                  if (!isUnlocked) {
                    _showSnack('Dieses Foto ist gesperrt. Upgrade für mehr Fotos.');
                    _openUpgrade();
                    return;
                  }

                  // ✅ Nur die freigeschalteten Fotos ins Vollbild geben
                  final startIndex = index.clamp(0, unlockedPhotos.length - 1);
                  _openFullscreen(unlockedPhotos, startIndex);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Hinweisbox
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _maxVisible >= 999
                      ? 'Gold aktiv: Du siehst alle Fotos ✨'
                      : 'Tipp: Upgrade für mehr Fotos & Sichtbarkeit ✨',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final ProfilePhoto photo;
  final bool unlocked;
  final VoidCallback onTap;

  const _Thumb({
    required this.photo,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: unlocked
                  ? Image.network(photo.fullUrl, fit: BoxFit.cover)
                  : _LockedImage(photo: photo),
            ),
            if (!unlocked) ...[
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.20)),
              ),
              const Positioned(
                right: 6,
                top: 6,
                child: Icon(Icons.lock, color: Colors.white, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LockedImage extends StatelessWidget {
  final ProfilePhoto photo;

  const _LockedImage({required this.photo});

  @override
  Widget build(BuildContext context) {
    // Wenn blur_url in DB gepflegt ist -> nutzen wir das
    if (photo.blurUrl != null && photo.blurUrl!.isNotEmpty) {
      return Image.network(photo.blurUrl!, fit: BoxFit.cover);
    }

    // Fallback: Full Image + Blur Filter
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Image.network(photo.fullUrl, fit: BoxFit.cover),
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<ProfilePhoto> photos;
  final int startIndex;

  const _FullscreenGallery({
    required this.photos,
    required this.startIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Fotos'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        itemBuilder: (context, i) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                widget.photos[i].fullUrl,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}