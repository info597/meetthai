import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/subscription_service.dart';
import 'services/subscription_state.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final TextEditingController _betaCodeController = TextEditingController();

  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;
  bool _activatingBeta = false;
  String? _error;

  Package? _premiumMonthly;
  Package? _premiumSemiannual;
  Package? _premiumYearly;

  Package? _goldMonthly;
  Package? _goldSemiannual;
  Package? _goldYearly;

  bool _isPremiumActive = false;
  bool _isGoldActive = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _betaCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadOfferings(),
        _loadCurrentPlanState(),
      ]);

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final t = AppStrings.of(context);

      setState(() {
        _loading = false;
        _error = t.isGerman
            ? 'Upgrade-Daten konnten nicht geladen werden: $e'
            : t.isThai
                ? 'ไม่สามารถโหลดข้อมูลอัปเกรดได้: $e'
                : 'Upgrade data could not be loaded: $e';
      });
    }
  }

  Future<void> _loadCurrentPlanState() async {
    await SubscriptionState.instance.refresh();

    _isGoldActive = SubscriptionState.instance.isGold;
    _isPremiumActive = SubscriptionState.instance.isPremium;
  }

  Future<void> _loadOfferings() async {
    final offerings = await SubscriptionService.instance.getOfferings();
    final current = offerings?.current;

    if (current == null) {
      return;
    }

    Package? findByProductId(String productId) {
      for (final pkg in current.availablePackages) {
        if (pkg.storeProduct.identifier == productId) {
          return pkg;
        }
      }
      return null;
    }

    _premiumMonthly = findByProductId('premium_monthly');
    _premiumSemiannual = findByProductId('premium_semiannual');
    _premiumYearly = findByProductId('premium_yearly');

    _goldMonthly = findByProductId('gold_monthly');
    _goldSemiannual = findByProductId('gold_semiannual');
    _goldYearly = findByProductId('gold_yearly');
  }

  Future<void> _activateBetaCode() async {
    if (_activatingBeta || _purchasing || _restoring) return;

    final t = AppStrings.of(context);
    final code = _betaCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = t.isGerman
            ? 'Bitte gib dein Passwort ein.'
            : t.isThai
                ? 'กรุณาใส่รหัสผ่าน'
                : 'Please enter your password.';
      });
      return;
    }

    setState(() {
      _activatingBeta = true;
      _error = null;
    });

    try {
      final success =
          await SubscriptionService.instance.activateBetaTesterCode(code);

      if (!mounted) return;

      if (!success) {
        setState(() {
          _activatingBeta = false;
          _error = t.isGerman
              ? 'Passwort ist ungültig.'
              : t.isThai
                  ? 'รหัสผ่านไม่ถูกต้อง'
                  : 'Password is invalid.';
        });
        return;
      }

      await _loadCurrentPlanState();

      if (!mounted) return;

      setState(() {
        _activatingBeta = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Beta-Zugang wurde freigeschaltet.'
                : t.isThai
                    ? 'เปิดใช้งานสิทธิ์เบต้าแล้ว'
                    : 'Beta access has been unlocked.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _activatingBeta = false;
        _error = t.isGerman
            ? 'Beta-Zugang konnte nicht aktiviert werden: $e'
            : t.isThai
                ? 'ไม่สามารถเปิดใช้งานสิทธิ์เบต้าได้: $e'
                : 'Beta access could not be activated: $e';
      });
    }
  }

  Future<void> _buyPackage(Package package) async {
    if (_purchasing || _restoring || _activatingBeta) return;

    final t = AppStrings.of(context);

    setState(() {
      _purchasing = true;
      _error = null;
    });

    try {
      await SubscriptionService.instance.purchasePackage(package);
      await _loadCurrentPlanState();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Kauf erfolgreich freigeschaltet.'
                : t.isThai
                    ? 'เปิดใช้งานการซื้อสำเร็จแล้ว'
                    : 'Purchase unlocked successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (!mounted) return;

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        setState(() {
          _purchasing = false;
        });
        return;
      }

      setState(() {
        _purchasing = false;
        _error = t.isGerman
            ? 'Kauf fehlgeschlagen: ${e.message ?? e.code}'
            : t.isThai
                ? 'การซื้อไม่สำเร็จ: ${e.message ?? e.code}'
                : 'Purchase failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchasing = false;
        _error = t.isGerman
            ? 'Kauf fehlgeschlagen: $e'
            : t.isThai
                ? 'การซื้อไม่สำเร็จ: $e'
                : 'Purchase failed: $e';
      });
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring || _purchasing || _activatingBeta) return;

    final t = AppStrings.of(context);

    setState(() {
      _restoring = true;
      _error = null;
    });

    try {
      await SubscriptionService.instance.restorePurchases();
      await _loadCurrentPlanState();

      if (!mounted) return;

      setState(() {
        _restoring = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isGerman
                ? 'Käufe wurden wiederhergestellt.'
                : t.isThai
                    ? 'กู้คืนการซื้อแล้ว'
                    : 'Purchases were restored.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _error = t.isGerman
            ? 'Wiederherstellen fehlgeschlagen: ${e.message ?? e.code}'
            : t.isThai
                ? 'การกู้คืนไม่สำเร็จ: ${e.message ?? e.code}'
                : 'Restore failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _error = t.isGerman
            ? 'Wiederherstellen fehlgeschlagen: $e'
            : t.isThai
                ? 'การกู้คืนไม่สำเร็จ: $e'
                : 'Restore failed: $e';
      });
    }
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  Widget _buildBetaTesterCard() {
    final t = AppStrings.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blue.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.isGerman
                      ? 'Beta-Tester Zugang'
                      : t.isThai
                          ? 'สิทธิ์ผู้ทดสอบเบต้า'
                          : 'Beta tester access',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.isGerman
                ? 'Wenn du ein Test-Passwort bekommen hast, kannst du hier Gold kostenlos freischalten.'
                : t.isThai
                    ? 'หากคุณได้รับรหัสผ่านทดสอบ คุณสามารถปลดล็อก Gold ฟรีได้ที่นี่'
                    : 'If you received a test password, you can unlock Gold for free here.',
            style: TextStyle(
              color: Colors.black.withOpacity(0.68),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _betaCodeController,
            textCapitalization: TextCapitalization.characters,
            enabled: !_activatingBeta && !_purchasing && !_restoring,
            decoration: InputDecoration(
              labelText: t.isGerman
                  ? 'Passwort'
                  : t.isThai
                      ? 'รหัสผ่าน'
                      : 'Password',
              hintText: t.isGerman
                  ? 'Passwort eingeben'
                  : t.isThai
                      ? 'ใส่รหัสผ่าน'
                      : 'Enter password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: (_activatingBeta || _purchasing || _restoring)
                ? null
                : _activateBetaCode,
            icon: _activatingBeta
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded),
            label: Text(
              t.isGerman
                  ? 'Kostenlos freischalten'
                  : t.isThai
                      ? 'ปลดล็อกฟรี'
                      : 'Unlock for free',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticPlanCard({
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color backgroundColor,
    required List<String> features,
    required String footerText,
    required String buttonText,
    String? badgeText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.24),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.68),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accentColor.withOpacity(0.22),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => _buildFeatureRow(
              icon: Icons.check_circle_rounded,
              text: feature,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footerText,
            style: TextStyle(
              color: Colors.black.withOpacity(0.66),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_rounded),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageButton({
    required Package package,
    required Color color,
    required bool highlighted,
    String? badge,
  }) {
    final product = package.storeProduct;
    final price = product.priceString;
    final title = product.title.trim().isNotEmpty
        ? product.title.trim()
        : product.identifier;
    final description = product.description.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlighted ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? color.withOpacity(0.35) : Colors.black12,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (_purchasing || _restoring || _activatingBeta)
            ? null
            : () => _buyPackage(package),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.62),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _purchasing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      price,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicPlanCard({
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color backgroundColor,
    required List<String> features,
    required String footerText,
    required List<Package> packages,
    String? badgeText,
    bool highlight = false,
    bool isActive = false,
  }) {
    final t = AppStrings.of(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.24),
          width: highlight ? 1.6 : 1.0,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.68),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accentColor.withOpacity(0.22),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => _buildFeatureRow(
              icon: Icons.check_circle_rounded,
              text: feature,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footerText,
            style: TextStyle(
              color: Colors.black.withOpacity(0.66),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (isActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_rounded),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black87,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  t.isGerman
                      ? 'Aktiver Plan'
                      : t.isThai
                          ? 'แผนที่ใช้งานอยู่'
                          : 'Active plan',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else if (packages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                t.isGerman
                    ? 'Aktuell keine Pakete verfügbar.'
                    : t.isThai
                        ? 'ขณะนี้ยังไม่มีแพ็กเกจ'
                        : 'No packages currently available.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            ...packages.asMap().entries.map(
              (entry) => _buildPackageButton(
                package: entry.value,
                color: accentColor,
                highlighted: highlight && entry.key == 0,
                badge: highlight && entry.key == 0
                    ? (t.isGerman
                        ? 'TOP'
                        : t.isThai
                            ? 'แนะนำ'
                            : 'TOP')
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  List<Package> get _premiumPackages => [
        if (_premiumMonthly != null) _premiumMonthly!,
        if (_premiumSemiannual != null) _premiumSemiannual!,
        if (_premiumYearly != null) _premiumYearly!,
      ];

  List<Package> get _goldPackages => [
        if (_goldMonthly != null) _goldMonthly!,
        if (_goldSemiannual != null) _goldSemiannual!,
        if (_goldYearly != null) _goldYearly!,
      ];

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    final heroTitle = t.isGerman
        ? 'Mehr Likes. Mehr Matches. Mehr Chats. ❤️'
        : t.isThai
            ? 'ไลก์มากขึ้น แมตช์มากขึ้น แชตมากขึ้น ❤️'
            : 'More likes. More matches. More chats. ❤️';

    final heroSubtitle = t.isGerman
        ? 'Wähle den Plan, der am besten zu dir passt. Free ist ideal zum Starten, Premium gibt dir mehr Chancen pro Tag und Gold hebt deine Limits fast komplett auf.'
        : t.isThai
            ? 'เลือกแพ็กเกจที่เหมาะกับคุณที่สุด Free เหมาะสำหรับการเริ่มต้น Premium ให้โอกาสคุณมากขึ้นในแต่ละวัน และ Gold แทบจะปลดล็อกทุกลิมิต'
            : 'Choose the plan that fits you best. Free is ideal to start, Premium gives you more chances per day, and Gold almost completely removes your limits.';

    final whyTitle = t.isGerman
        ? 'Warum sich ein Upgrade lohnt'
        : t.isThai
            ? 'ทำไมการอัปเกรดจึงคุ้มค่า'
            : 'Why an upgrade is worth it';

    final whyText = t.isGerman
        ? 'Mit mehr sichtbaren Likes und mehr Antworten pro Tag erhöhst du deine Chancen auf ein Match deutlich. Besonders Premium ist ideal, wenn du regelmäßig aktiv bist und nicht jeden Tag früh an Grenzen stoßen willst.'
        : t.isThai
            ? 'เมื่อเห็นไลก์ได้มากขึ้นและตอบกลับได้มากขึ้นต่อวัน โอกาสในการได้แมตช์ก็สูงขึ้นอย่างชัดเจน โดยเฉพาะ Premium เหมาะมากถ้าคุณใช้งานเป็นประจำและไม่อยากชนลิมิตเร็วทุกวัน'
            : 'With more visible likes and more replies per day, you significantly increase your chances of getting a match. Premium is especially ideal if you are regularly active and do not want to hit limits too early every day.';

    final noteText = t.isGerman
        ? 'Hinweis: Antworten auf Likes zählen zu deinen täglichen Likes mit dazu.'
        : t.isThai
            ? 'หมายเหตุ: การตอบกลับไลก์จะนับรวมในจำนวนไลก์ต่อวันของคุณด้วย'
            : 'Note: Replies to likes also count toward your daily likes.';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.isGerman
              ? 'Upgrade'
              : t.isThai
                  ? 'อัปเกรด'
                  : 'Upgrade',
        ),
        actions: [
          IconButton(
            tooltip: t.home,
            icon: const Icon(Icons.home_rounded),
            onPressed: _goHome,
          ),
          TextButton(
            onPressed: (_loading || _purchasing || _restoring || _activatingBeta)
                ? null
                : _restorePurchases,
            child: _restoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    t.isGerman
                        ? 'Restore'
                        : t.isThai
                            ? 'กู้คืน'
                            : 'Restore',
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      heroTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      heroSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.68),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.18)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    _buildBetaTesterCard(),
                    const SizedBox(height: 16),
                    _buildStaticPlanCard(
                      title: 'FREE',
                      subtitle: t.isGerman
                          ? 'Zum Starten'
                          : t.isThai
                              ? 'สำหรับเริ่มต้น'
                              : 'To get started',
                      accentColor: Colors.grey.shade700,
                      backgroundColor: Colors.grey.withOpacity(0.08),
                      features: [
                        t.isGerman
                            ? '10 Likes pro Tag senden'
                            : t.isThai
                                ? 'ส่งได้ 10 ไลก์ต่อวัน'
                                : 'Send 10 likes per day',
                        t.isGerman
                            ? 'Die ersten 10 Likes sehen'
                            : t.isThai
                                ? 'เห็น 10 ไลก์แรก'
                                : 'See the first 10 likes',
                        t.isGerman
                            ? 'Die ersten 10 Likes beantworten'
                            : t.isThai
                                ? 'ตอบกลับ 10 ไลก์แรก'
                                : 'Reply to the first 10 likes',
                        t.isGerman
                            ? 'Weitere Likes gesperrt'
                            : t.isThai
                                ? 'ไลก์เพิ่มเติมถูกล็อก'
                                : 'Additional likes locked',
                      ],
                      footerText: t.isGerman
                          ? 'Ideal, um die App kennenzulernen.'
                          : t.isThai
                              ? 'เหมาะสำหรับเริ่มทำความรู้จักกับแอป'
                              : 'Ideal for getting to know the app.',
                      buttonText: (!_isPremiumActive && !_isGoldActive)
                          ? (t.isGerman
                              ? 'Aktiver Einstieg'
                              : t.isThai
                                  ? 'แผนเริ่มต้นที่ใช้งานอยู่'
                                  : 'Current starter plan')
                          : (t.isGerman
                              ? 'Basis-Plan'
                              : t.isThai
                                  ? 'แผนพื้นฐาน'
                                  : 'Basic plan'),
                      badgeText: t.isGerman
                          ? 'BASIS'
                          : t.isThai
                              ? 'พื้นฐาน'
                              : 'BASIC',
                    ),
                    const SizedBox(height: 16),
                    _buildDynamicPlanCard(
                      title: 'PREMIUM',
                      subtitle: t.isGerman
                          ? 'Mehr Chancen pro Tag'
                          : t.isThai
                              ? 'โอกาสมากขึ้นต่อวัน'
                              : 'More chances per day',
                      accentColor: Colors.pink,
                      backgroundColor: Colors.pink.withOpacity(0.10),
                      highlight: true,
                      badgeText: (_isPremiumActive && !_isGoldActive)
                          ? (t.isGerman
                              ? 'AKTIV'
                              : t.isThai
                                  ? 'ใช้งานอยู่'
                                  : 'ACTIVE')
                          : (t.isGerman
                              ? 'BELIEBT'
                              : t.isThai
                                  ? 'ยอดนิยม'
                                  : 'POPULAR'),
                      isActive: _isPremiumActive && !_isGoldActive,
                      features: [
                        t.isGerman
                            ? '25 Likes pro Tag senden'
                            : t.isThai
                                ? 'ส่งได้ 25 ไลก์ต่อวัน'
                                : 'Send 25 likes per day',
                        t.isGerman
                            ? 'Die ersten 25 Likes sehen'
                            : t.isThai
                                ? 'เห็น 25 ไลก์แรก'
                                : 'See the first 25 likes',
                        t.isGerman
                            ? 'Die ersten 25 Likes beantworten'
                            : t.isThai
                                ? 'ตอบกลับ 25 ไลก์แรก'
                                : 'Reply to the first 25 likes',
                        t.isGerman
                            ? 'Mehr Matches und schnellere Kontakte'
                            : t.isThai
                                ? 'แมตช์มากขึ้นและติดต่อได้เร็วขึ้น'
                                : 'More matches and faster connections',
                      ],
                      footerText: t.isGerman
                          ? 'Perfekt, wenn du aktiver liken und mehr Chancen pro Tag nutzen willst.'
                          : t.isThai
                              ? 'เหมาะมากถ้าคุณต้องการกดไลก์มากขึ้นและใช้โอกาสต่อวันได้มากขึ้น'
                              : 'Perfect if you want to like more actively and use more chances per day.',
                      packages: _premiumPackages,
                    ),
                    const SizedBox(height: 16),
                    _buildDynamicPlanCard(
                      title: 'GOLD',
                      subtitle: t.isGerman
                          ? 'Maximale Freiheit'
                          : t.isThai
                              ? 'อิสระสูงสุด'
                              : 'Maximum freedom',
                      accentColor: Colors.amber,
                      backgroundColor: Colors.amber.withOpacity(0.12),
                      badgeText: _isGoldActive
                          ? (t.isGerman
                              ? 'AKTIV'
                              : t.isThai
                                  ? 'ใช้งานอยู่'
                                  : 'ACTIVE')
                          : (t.isGerman
                              ? 'MAX'
                              : t.isThai
                                  ? 'สูงสุด'
                                  : 'MAX'),
                      isActive: _isGoldActive,
                      features: [
                        t.isGerman
                            ? 'Unbegrenzte Likes senden'
                            : t.isThai
                                ? 'ส่งไลก์ได้ไม่จำกัด'
                                : 'Send unlimited likes',
                        t.isGerman
                            ? 'Alle Likes sehen'
                            : t.isThai
                                ? 'เห็นไลก์ทั้งหมด'
                                : 'See all likes',
                        t.isGerman
                            ? 'Alle Likes beantworten'
                            : t.isThai
                                ? 'ตอบกลับไลก์ทั้งหมด'
                                : 'Reply to all likes',
                        t.isGerman
                            ? 'Maximale Reichweite und volle Freiheit'
                            : t.isThai
                                ? 'การมองเห็นสูงสุดและอิสระเต็มที่'
                                : 'Maximum reach and full freedom',
                      ],
                      footerText: t.isGerman
                          ? 'Für Nutzer, die wirklich keine Limits mehr wollen.'
                          : t.isThai
                              ? 'สำหรับผู้ใช้ที่ไม่ต้องการมีลิมิตอีกต่อไป'
                              : 'For users who truly do not want limits anymore.',
                      packages: _goldPackages,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.pink,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  whyTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            whyText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.7),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      noteText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.56),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}