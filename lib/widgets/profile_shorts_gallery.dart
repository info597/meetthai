import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../upgrade_screen.dart';

class ProfileShortsGallery extends StatefulWidget {
  final String profileUserId;

  const ProfileShortsGallery({
    super.key,
    required this.profileUserId,
  });

  @override
  State<ProfileShortsGallery> createState() => _ProfileShortsGalleryState();
}

class _ProfileShortsGalleryState extends State<ProfileShortsGallery> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<_ShortItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final rows = await _supa
          .from('profile_shorts')
          .select('id, user_id, video_url, thumbnail_url, created_at')
          .eq('user_id', widget.profileUserId)
          .order('created_at', ascending: false);

      final list = <_ShortItem>[];
      for (final r in rows as List) {
        list.add(_ShortItem(
          id: (r['id'] ?? '').toString(),
          userId: (r['user_id'] ?? '').toString(),
          videoUrl: (r['video_url'] ?? '').toString(),
          thumbnailUrl: (r['thumbnail_url'] ?? '')?.toString(),
        ));
      }

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Fehler beim Laden der Shorts: $e';
        _loading = false;
      });
    }
  }

  void _openUpgrade() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );
  }

  Future<bool> _consumeShortViewQuota() async {
    try {
      await _supa.rpc('consume_quota', params: {
        'p_action': 'shorts_viewed',
        'p_amount': 1,
      });
      return true;
    } catch (e) {
      final msg = e.toString();

      if (msg.contains('LIMIT_REACHED')) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tageslimit für Shorts erreicht. Upgrade für mehr Shorts ⭐✨'),
          ),
        );
        _openUpgrade();
        return false;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Shorts-Limit: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _openPlayer(int startIndex) async {
    final ok = await _consumeShortViewQuota();
    if (!ok) return;

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShortsPlayerScreen(
          items: _items,
          startIndex: startIndex,
        ),
      ),
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

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Neu laden'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Noch keine Shorts hochgeladen.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Shorts (${_items.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Shorts neu laden',
            ),
          ],
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final s = _items[i];
              return _ShortThumb(
                thumbnailUrl: (s.thumbnailUrl ?? '').trim().isEmpty ? null : s.thumbnailUrl,
                onTap: () => _openPlayer(i),
              );
            },
          ),
        ),

        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Shorts zeigen deine Persönlichkeit – das erhöht Matches deutlich ✨',
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

class _ShortThumb extends StatelessWidget {
  final String? thumbnailUrl;
  final VoidCallback onTap;

  const _ShortThumb({
    required this.thumbnailUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: thumbnailUrl != null
                  ? Image.network(thumbnailUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.black.withOpacity(0.08),
                      child: const Center(child: Icon(Icons.videocam_rounded, size: 34)),
                    ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.10)),
            ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortsPlayerScreen extends StatefulWidget {
  final List<_ShortItem> items;
  final int startIndex;

  const _ShortsPlayerScreen({
    required this.items,
    required this.startIndex,
  });

  @override
  State<_ShortsPlayerScreen> createState() => _ShortsPlayerScreenState();
}

class _ShortsPlayerScreenState extends State<_ShortsPlayerScreen> {
  late final PageController _page;
  VideoPlayerController? _vc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: widget.startIndex);
    _initVideo(widget.startIndex);
  }

  Future<void> _initVideo(int index) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _vc?.dispose();
      final url = widget.items[index].videoUrl;

      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _vc = c;

      await c.initialize();
      await c.setLooping(true);
      await c.play();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Video konnte nicht geladen werden: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Shorts (${(_page.hasClients ? (_page.page ?? widget.startIndex) : widget.startIndex).round() + 1}/$total)'),
      ),
      body: PageView.builder(
        controller: _page,
        itemCount: total,
        onPageChanged: (i) => _initVideo(i),
        itemBuilder: (_, i) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.white)),
              ),
            );
          }

          final c = _vc;
          if (c == null || !c.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          );
        },
      ),
    );
  }
}

class _ShortItem {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;

  _ShortItem({
    required this.id,
    required this.userId,
    required this.videoUrl,
    required this.thumbnailUrl,
  });
}