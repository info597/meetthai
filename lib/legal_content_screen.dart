import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum LegalContentType {
  privacy,
  terms,
  imprint,
}

class LegalContentScreen extends StatefulWidget {
  final LegalContentType type;

  const LegalContentScreen({
    super.key,
    required this.type,
  });

  @override
  State<LegalContentScreen> createState() => _LegalContentScreenState();
}

class _LegalContentScreenState extends State<LegalContentScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _title;
  String? _content;
  String? _fallbackUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  String get _defaultTitle {
    switch (widget.type) {
      case LegalContentType.privacy:
        return 'Datenschutz';
      case LegalContentType.terms:
        return 'AGB / Terms';
      case LegalContentType.imprint:
        return 'Impressum';
    }
  }

  String get _textKey {
    switch (widget.type) {
      case LegalContentType.privacy:
        return 'privacy_text';
      case LegalContentType.terms:
        return 'terms_text';
      case LegalContentType.imprint:
        return 'imprint_text';
    }
  }

  String get _titleKey {
    switch (widget.type) {
      case LegalContentType.privacy:
        return 'privacy_title';
      case LegalContentType.terms:
        return 'terms_title';
      case LegalContentType.imprint:
        return 'imprint_title';
    }
  }

  String get _urlKey {
    switch (widget.type) {
      case LegalContentType.privacy:
        return 'privacy_url';
      case LegalContentType.terms:
        return 'terms_url';
      case LegalContentType.imprint:
        return 'imprint_url';
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _supabase
          .from('app_settings')
          .select('key, value')
          .inFilter('key', [_textKey, _titleKey, _urlKey]);

      final map = <String, String>{};

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final key = row['key']?.toString().trim();
        final value = row['value']?.toString() ?? '';
        if (key == null || key.isEmpty) continue;
        map[key] = value;
      }

      final loadedTitle = (map[_titleKey] ?? '').trim();
      final loadedText = (map[_textKey] ?? '').trim();
      final loadedUrl = (map[_urlKey] ?? '').trim();

      if (!mounted) return;

      setState(() {
        _title = loadedTitle.isNotEmpty ? loadedTitle : _defaultTitle;
        _content = loadedText.isNotEmpty ? loadedText : null;
        _fallbackUrl = loadedUrl.isNotEmpty ? loadedUrl : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _title = _defaultTitle;
        _error = 'Inhalt konnte nicht geladen werden: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ungültiger Link')),
      );
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link konnte nicht geöffnet werden')),
      );
    }
  }

  Future<void> _copyText() async {
    final text = _content?.trim();
    if (text == null || text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text kopiert')),
    );
  }

  Widget _buildEmptyFallback() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 42),
              const SizedBox(height: 12),
              Text(
                'Für diesen Bereich ist noch kein interner Text hinterlegt.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Du kannst den Text direkt in app_settings speichern oder vorübergehend den externen Link nutzen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.68),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (_fallbackUrl != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openExternal(_fallbackUrl!),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Extern öffnen'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_content == null || _content!.trim().isEmpty) {
      return _buildEmptyFallback();
    }

    return RefreshIndicator(
      onRefresh: _loadContent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title ?? _defaultTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText.rich(
                  TextSpan(
                    children: _content!
                        .split('\n')
                        .map(
                          (line) => TextSpan(
                            text: '$line\n\n',
                          ),
                        )
                        .toList(),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _copyText,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Text kopieren'),
          ),
          if (_fallbackUrl != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openExternal(_fallbackUrl!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Externe Version öffnen'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? _defaultTitle),
      ),
      body: _buildContent(),
    );
  }
}