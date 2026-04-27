import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_content_screen.dart';
import 'profile_edit_screen.dart';
import 'theme.dart';
import 'upgrade_screen.dart';

enum _PlanType { free, premium, gold }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isDeletingAccount = false;
  String? _email;
  _PlanType _plan = _PlanType.free;

  Map<String, dynamic>? _appSettings;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadUserAndPlan(),
      _loadAppSettings(),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUserAndPlan() async {
    final user = _supabase.auth.currentUser;

    if (!mounted) return;
    setState(() {
      _email = user?.email;
    });

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _plan = _PlanType.free;
      });
      return;
    }

    try {
      final data = await _supabase
          .from('profiles')
          .select('is_premium, is_gold')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      _PlanType plan = _PlanType.free;

      if (data != null) {
        final isGold = data['is_gold'] == true;
        final isPremium = data['is_premium'] == true;

        if (isGold) {
          plan = _PlanType.gold;
        } else if (isPremium) {
          plan = _PlanType.premium;
        }
      }

      setState(() {
        _plan = plan;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plan = _PlanType.free;
      });
    }
  }

  Future<void> _loadAppSettings() async {
    try {
      final rows = await _supabase.from('app_settings').select('key, value');

      final map = <String, dynamic>{};

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final key = row['key']?.toString().trim();
        if (key == null || key.isEmpty) continue;
        map[key] = row['value'];
      }

      if (!mounted) return;
      setState(() {
        _appSettings = map;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appSettings = {};
      });
    }
  }

  String get _planLabel {
    switch (_plan) {
      case _PlanType.gold:
        return 'Gold';
      case _PlanType.premium:
        return 'Premium';
      case _PlanType.free:
        return 'Free';
    }
  }

  Color get _planColor {
    switch (_plan) {
      case _PlanType.gold:
        return AppColors.accentGold;
      case _PlanType.premium:
        return AppColors.primary;
      case _PlanType.free:
        return Colors.grey;
    }
  }

  bool get _isPremiumOrGold {
    return _plan == _PlanType.premium || _plan == _PlanType.gold;
  }

  String? _settingString(String key) {
    final value = _appSettings?[key];
    if (value == null) return null;

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? get _supportEmail => _settingString('support_email');
  String? get _supportTelegram => _settingString('support_telegram');
  String? get _supportUrl => _settingString('support_url');
  String? get _privacyUrl => _settingString('privacy_url');
  String? get _termsUrl => _settingString('terms_url');
  String? get _imprintUrl => _settingString('imprint_url');

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Account endgültig ausblenden?'),
              content: const Text(
                'Dein Profil wird deaktiviert, versteckt und du wirst ausgeloggt.\n\n'
                'Dieser Schritt ist aktuell als Soft Delete umgesetzt.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Ja, löschen'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      await _supabase.rpc('delete_my_account');
      await _supabase.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dein Account wurde deaktiviert.'),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account konnte nicht gelöscht werden: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
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

  Future<void> _openEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
    );

    final ok = await launchUrl(uri);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail App konnte nicht geöffnet werden')),
      );
    }
  }

  Future<void> _openTelegram(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      await _openExternal(raw);
      return;
    }

    final username = raw.startsWith('@') ? raw.substring(1) : raw;
    await _openExternal('https://t.me/$username');
  }

  Future<void> _openProfileEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileEditScreen(),
      ),
    );

    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _openUpgrade() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UpgradeScreen(),
      ),
    );

    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _openLegalPage(LegalContentType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalContentScreen(type: type),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildSupportSection() {
    final user = _supabase.auth.currentUser;
    final premiumAllowed = _isPremiumOrGold && user != null;

    final children = <Widget>[];

    if (premiumAllowed) {
      if (_supportTelegram != null) {
        children.add(
          _buildActionTile(
            icon: Icons.send_rounded,
            title: 'Premium Support via Telegram',
            subtitle: _supportTelegram,
            onTap: () => _openTelegram(_supportTelegram!),
          ),
        );
      }

      if (_supportEmail != null) {
        children.add(
          _buildActionTile(
            icon: Icons.email_outlined,
            title: 'Premium Support via E-Mail',
            subtitle: _supportEmail,
            onTap: () => _openEmail(_supportEmail!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Kopieren',
                  onPressed: () => _copyToClipboard(
                    _supportEmail!,
                    'Support-E-Mail kopiert',
                  ),
                  icon: const Icon(Icons.copy_rounded),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
      }

      if (_supportUrl != null) {
        children.add(
          _buildActionTile(
            icon: Icons.bug_report_rounded,
            title: 'Feedback & Bugs melden',
            subtitle: 'Problem melden oder Feedback senden',
            onTap: () => _openExternal(_supportUrl!),
          ),
        );
      }

      if (children.isEmpty) {
        children.add(
          const Text(
            'Noch keine Support-Kontaktdaten hinterlegt.',
          ),
        );
      }
    } else {
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Premium Support ist für Premium- und Gold-Mitglieder verfügbar.',
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
      children.add(
        ElevatedButton.icon(
          onPressed: _openUpgrade,
          icon: const Icon(Icons.workspace_premium_rounded),
          label: const Text('Upgrade öffnen'),
        ),
      );
    }

    return _buildSectionCard(
      title: 'Support',
      children: children,
    );
  }

  Widget _buildLegalSection() {
    final children = <Widget>[
      _buildActionTile(
        icon: Icons.privacy_tip_outlined,
        title: 'Datenschutz',
        subtitle: 'In der App öffnen',
        onTap: () => _openLegalPage(LegalContentType.privacy),
      ),
      _buildActionTile(
        icon: Icons.description_outlined,
        title: 'AGB / Terms',
        subtitle: 'In der App öffnen',
        onTap: () => _openLegalPage(LegalContentType.terms),
      ),
      _buildActionTile(
        icon: Icons.gavel_rounded,
        title: 'Impressum',
        subtitle: 'In der App öffnen',
        onTap: () => _openLegalPage(LegalContentType.imprint),
      ),
    ];

    if (_privacyUrl != null || _termsUrl != null || _imprintUrl != null) {
      children.add(const SizedBox(height: 6));
      children.add(
        Text(
          'Falls kein interner Text hinterlegt ist, kann optional die externe Version verwendet werden.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.62),
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      );
    }

    return _buildSectionCard(
      title: 'Datenschutz & Rechtliches',
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen & Account'),
      ),
      body: Stack(
        children: [
          if (_isLoading || _isDeletingAccount)
            const LinearProgressIndicator(minHeight: 2),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionCard(
                title: 'Account',
                children: [
                  if (user == null) ...[
                    const Text(
                      'Du bist aktuell nicht eingeloggt.',
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/auth');
                      },
                      child: const Text('Zum Login'),
                    ),
                  ] else ...[
                    Text(
                      _email ?? '(keine E-Mail gefunden)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Abo-Status: '),
                        Chip(
                          label: Text(
                            _planLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _planColor,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Profil & Abo',
                children: [
                  ElevatedButton.icon(
                    onPressed: _openProfileEdit,
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('Profil bearbeiten'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openUpgrade,
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Upgrade / Abo verwalten'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSupportSection(),
              const SizedBox(height: 16),
              _buildLegalSection(),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Sicherheit',
                children: [
                  if (user != null) ...[
                    OutlinedButton.icon(
                      onPressed: _isDeletingAccount ? null : _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Abmelden'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isDeletingAccount ? null : _deleteAccount,
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.redAccent,
                      ),
                      label: Text(
                        _isDeletingAccount
                            ? 'Account wird gelöscht...'
                            : 'Account löschen',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Melde dich an, um dich abzumelden oder deinen Account zu verwalten.',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}