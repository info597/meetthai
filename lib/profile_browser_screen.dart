import 'package:flutter/material.dart';

import 'i18n/app_strings.dart';
import 'services/discovery_service.dart';
import 'user_profile_screen.dart';

enum ProfileBrowserSortMode {
  onlineFirst,
  newestFirst,
  popularityFirst,
  goldFirst,
  premiumFirst,
  ageAscending,
  ageDescending,
  heightAscending,
  heightDescending,
  weightAscending,
  weightDescending,
}

class ProfileBrowserScreen extends StatefulWidget {
  const ProfileBrowserScreen({super.key});

  @override
  State<ProfileBrowserScreen> createState() => _ProfileBrowserScreenState();
}

class _ProfileBrowserScreenState extends State<ProfileBrowserScreen> {
  bool _loading = true;
  String? _error;

  final List<DiscoveryProfile> _allProfiles = [];

  final TextEditingController _searchCtrl = TextEditingController();

  String? _gender;
  String? _hairColor;
  String? _eyeColor;
  String? _country;
  String? _originCountry;
  String? _province;
  String? _desiredPartner;
  String _areaFilter = 'worldwide';

  bool _onlyOnline = false;
  bool _onlyGold = false;
  bool _onlyPremium = false;

  RangeValues _ageRange = const RangeValues(18, 99);
  RangeValues _heightRange = const RangeValues(100, 250);
  RangeValues _weightRange = const RangeValues(35, 200);

  ProfileBrowserSortMode _sortMode = ProfileBrowserSortMode.onlineFirst;

  AppStrings get _t => AppStrings.of(context);

  List<String> get _genderOptions => const [
        'Männlich',
        'Weiblich',
        'Ladyboy',
        'Divers',
      ];

  List<String> get _desiredPartnerOptions => const [
        'Male',
        'Female',
        'Transgender',
      ];

  List<String> get _hairColorOptions => const [
        'Schwarz',
        'Dunkelbraun',
        'Braun',
        'Hellbraun',
        'Blond',
        'Dunkelblond',
        'Rot',
        'Grau',
        'Weiß',
        'Gefärbt',
        'Andere',
      ];

  List<String> get _eyeColorOptions => const [
        'Braun',
        'Dunkelbraun',
        'Hellbraun',
        'Blau',
        'Grün',
        'Grau',
        'Haselnuss',
        'Schwarz',
        'Andere',
      ];

  List<String> get _countryOptions {
    return _extractUniqueValues(
      _allProfiles.map((p) => p.country),
    );
  }

  List<String> get _originCountryOptions {
    return _extractUniqueValues(
      _allProfiles.map((p) => p.originCountry),
    );
  }

  List<String> get _provinceOptions {
    return _extractUniqueValues(
      _allProfiles.map((p) => p.province),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _title() {
    if (_t.isGerman) return 'Mitglieder';
    if (_t.isThai) return 'สมาชิก';
    return 'Members';
  }

  String _searchHint() {
    if (_t.isGerman) {
      return 'Name, Ort, Land, Herkunft, Job, Haarfarbe suchen';
    }
    if (_t.isThai) {
      return 'ค้นหาชื่อ เมือง ประเทศต้นทาง อาชีพ สีผม';
    }
    return 'Search name, city, country, origin, job, hair color';
  }

  String _filterTitle() {
    if (_t.isGerman) return 'Filter';
    if (_t.isThai) return 'ตัวกรอง';
    return 'Filters';
  }

  String _allLabel() {
    if (_t.isGerman) return 'Alle';
    if (_t.isThai) return 'ทั้งหมด';
    return 'All';
  }

  String _areaFilterTitle() {
    if (_t.isGerman) return 'Suchgebiet';
    if (_t.isThai) return 'พื้นที่ค้นหา';
    return 'Search area';
  }

  String _worldwideLabel() {
    if (_t.isGerman) return 'Weltweit';
    if (_t.isThai) return 'ทั่วโลก';
    return 'Worldwide';
  }

  bool _isThailandProfile(DiscoveryProfile profile) {
    final values = [
      profile.country,
      profile.originCountry,
      profile.province,
      profile.city,
    ];

    return values.whereType<String>().any((value) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'thailand' ||
          normalized == 'ไทย' ||
          normalized == 'ประเทศไทย' ||
          normalized.contains('thailand');
    });
  }

  String _sortTitle() {
    if (_t.isGerman) return 'Sortierung';
    if (_t.isThai) return 'การเรียงลำดับ';
    return 'Sorting';
  }

  String _countryLabel() {
    if (_t.isGerman) return 'Land';
    if (_t.isThai) return 'ประเทศ';
    return 'Country';
  }

  String _originCountryLabel() {
    if (_t.isGerman) return 'Herkunft';
    if (_t.isThai) return 'ประเทศต้นทาง';
    return 'Origin';
  }

  String _provinceLabel() {
    if (_t.isGerman) return 'Provinz / Region';
    if (_t.isThai) return 'จังหวัด / ภูมิภาค';
    return 'Province / region';
  }

  String _desiredPartnerLabel() {
    if (_t.isGerman) return 'Sucht nach';
    if (_t.isThai) return 'กำลังมองหา';
    return 'Looking for';
  }

  String _activeFiltersLabel(int count) {
    if (count <= 0) {
      if (_t.isGerman) return 'Keine Filter aktiv';
      if (_t.isThai) return 'ไม่มีตัวกรองที่เปิดอยู่';
      return 'No active filters';
    }

    if (_t.isGerman) return '$count Filter aktiv';
    if (_t.isThai) return 'เปิดใช้ตัวกรอง $count รายการ';
    return '$count active filters';
  }

  String _sortLabel(ProfileBrowserSortMode mode) {
    switch (mode) {
      case ProfileBrowserSortMode.onlineFirst:
        if (_t.isGerman) return 'Online zuerst';
        if (_t.isThai) return 'ออนไลน์ก่อน';
        return 'Online first';
      case ProfileBrowserSortMode.newestFirst:
        if (_t.isGerman) return 'Neueste zuerst';
        if (_t.isThai) return 'ใหม่ล่าสุดก่อน';
        return 'Newest first';
      case ProfileBrowserSortMode.popularityFirst:
        if (_t.isGerman) return 'Beliebtheit zuerst';
        if (_t.isThai) return 'ความนิยมก่อน';
        return 'Popularity first';
      case ProfileBrowserSortMode.goldFirst:
        if (_t.isGerman) return 'Gold zuerst';
        if (_t.isThai) return 'Gold ก่อน';
        return 'Gold first';
      case ProfileBrowserSortMode.premiumFirst:
        if (_t.isGerman) return 'Premium zuerst';
        if (_t.isThai) return 'Premium ก่อน';
        return 'Premium first';
      case ProfileBrowserSortMode.ageAscending:
        if (_t.isGerman) return 'Alter aufsteigend';
        if (_t.isThai) return 'อายุน้อยไปมาก';
        return 'Age ascending';
      case ProfileBrowserSortMode.ageDescending:
        if (_t.isGerman) return 'Alter absteigend';
        if (_t.isThai) return 'อายุมากไปน้อย';
        return 'Age descending';
      case ProfileBrowserSortMode.heightAscending:
        if (_t.isGerman) return 'Größe aufsteigend';
        if (_t.isThai) return 'ส่วนสูงน้อยไปมาก';
        return 'Height ascending';
      case ProfileBrowserSortMode.heightDescending:
        if (_t.isGerman) return 'Größe absteigend';
        if (_t.isThai) return 'ส่วนสูงมากไปน้อย';
        return 'Height descending';
      case ProfileBrowserSortMode.weightAscending:
        if (_t.isGerman) return 'Gewicht aufsteigend';
        if (_t.isThai) return 'น้ำหนักน้อยไปมาก';
        return 'Weight ascending';
      case ProfileBrowserSortMode.weightDescending:
        if (_t.isGerman) return 'Gewicht absteigend';
        if (_t.isThai) return 'น้ำหนักมากไปน้อย';
        return 'Weight descending';
    }
  }

  String _emptyText() {
    if (_t.isGerman) return 'Keine passenden Profile gefunden.';
    if (_t.isThai) return 'ไม่พบโปรไฟล์ที่ตรงกัน';
    return 'No matching profiles found.';
  }

  List<String> _extractUniqueValues(Iterable<String?> rawValues) {
    final values = <String>[];

    for (final raw in rawValues) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) continue;

      final alreadyExists = values.any(
        (item) => item.toLowerCase() == value.toLowerCase(),
      );

      if (!alreadyExists) {
        values.add(value);
      }
    }

    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profiles = await DiscoveryService.loadBrowseProfiles(limit: 250);

      if (!mounted) return;

      setState(() {
        _allProfiles
          ..clear()
          ..addAll(profiles);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _t.isGerman
            ? 'Profile konnten nicht geladen werden: $e'
            : _t.isThai
                ? 'ไม่สามารถโหลดโปรไฟล์ได้: $e'
                : 'Profiles could not be loaded: $e';
        _loading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _gender = null;
      _hairColor = null;
      _eyeColor = null;
      _country = null;
      _originCountry = null;
      _province = null;
      _desiredPartner = null;
      _areaFilter = 'worldwide';
      _onlyOnline = false;
      _onlyGold = false;
      _onlyPremium = false;
      _ageRange = const RangeValues(18, 99);
      _heightRange = const RangeValues(100, 250);
      _weightRange = const RangeValues(35, 200);
      _sortMode = ProfileBrowserSortMode.onlineFirst;
    });
  }

  bool _matchesTextSearch(DiscoveryProfile p, String query) {
    if (query.isEmpty) return true;

    final haystack = [
      p.displayName,
      p.city,
      p.originCountry,
      p.country,
      p.province,
      p.job,
      p.gender,
      p.hairColor,
      p.eyeColor,
      p.desiredPartner,
      p.hobbies,
      ...p.languages,
      if (p.age != null) p.age.toString(),
      if (p.heightCm != null) '${p.heightCm}',
      if (p.weightKg != null) '${p.weightKg}',
    ].whereType<String>().join(' ').toLowerCase();

    return haystack.contains(query);
  }

  bool _sameFilterValue(String? profileValue, String? filterValue) {
    if (filterValue == null || filterValue.trim().isEmpty) return true;

    final profileText = (profileValue ?? '').trim().toLowerCase();
    final filterText = filterValue.trim().toLowerCase();

    return profileText == filterText;
  }

  List<DiscoveryProfile> get _filteredProfiles {
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = _allProfiles.where((p) {
      if (!_matchesTextSearch(p, query)) return false;

      if (_onlyOnline && !p.isOnline) return false;
      if (_onlyGold && !p.isGold) return false;
      if (_onlyPremium && !p.isPremium) return false;
      if (_areaFilter == 'thailand' && !_isThailandProfile(p)) return false;

      if (!_sameFilterValue(p.gender, _gender)) return false;
      if (!_sameFilterValue(p.hairColor, _hairColor)) return false;
      if (!_sameFilterValue(p.eyeColor, _eyeColor)) return false;
      if (!_sameFilterValue(p.country, _country)) return false;
      if (!_sameFilterValue(p.originCountry, _originCountry)) return false;
      if (!_sameFilterValue(p.province, _province)) return false;
      if (!_sameFilterValue(p.desiredPartner, _desiredPartner)) return false;

      final age = p.age;
      if (age != null) {
        if (age < _ageRange.start.round() || age > _ageRange.end.round()) {
          return false;
        }
      }

      final height = p.heightCm;
      if (height != null) {
        if (height < _heightRange.start.round() ||
            height > _heightRange.end.round()) {
          return false;
        }
      }

      final weight = p.weightKg;
      if (weight != null) {
        if (weight < _weightRange.start.round() ||
            weight > _weightRange.end.round()) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortMode) {
        case ProfileBrowserSortMode.onlineFirst:
          return _compareOnlineGoldPremiumUpdated(a, b);

        case ProfileBrowserSortMode.newestFirst:
          return _compareDateDesc(a.updatedAt, b.updatedAt);

        case ProfileBrowserSortMode.popularityFirst:
          return _comparePopularity(a, b);

        case ProfileBrowserSortMode.goldFirst:
          final goldCompare = (b.isGold ? 1 : 0).compareTo(a.isGold ? 1 : 0);
          if (goldCompare != 0) return goldCompare;
          return _compareOnlineGoldPremiumUpdated(a, b);

        case ProfileBrowserSortMode.premiumFirst:
          final premiumCompare =
              (b.isPremium ? 1 : 0).compareTo(a.isPremium ? 1 : 0);
          if (premiumCompare != 0) return premiumCompare;
          return _compareOnlineGoldPremiumUpdated(a, b);

        case ProfileBrowserSortMode.ageAscending:
          return _compareNullableIntAsc(a.age, b.age);

        case ProfileBrowserSortMode.ageDescending:
          return _compareNullableIntDesc(a.age, b.age);

        case ProfileBrowserSortMode.heightAscending:
          return _compareNullableIntAsc(a.heightCm, b.heightCm);

        case ProfileBrowserSortMode.heightDescending:
          return _compareNullableIntDesc(a.heightCm, b.heightCm);

        case ProfileBrowserSortMode.weightAscending:
          return _compareNullableIntAsc(a.weightKg, b.weightKg);

        case ProfileBrowserSortMode.weightDescending:
          return _compareNullableIntDesc(a.weightKg, b.weightKg);
      }
    });

    return filtered;
  }

  int get _activeFilterCount {
    int count = 0;

    if (_searchCtrl.text.trim().isNotEmpty) count++;
    if (_gender != null) count++;
    if (_hairColor != null) count++;
    if (_eyeColor != null) count++;
    if (_country != null) count++;
    if (_originCountry != null) count++;
    if (_province != null) count++;
    if (_desiredPartner != null) count++;
    if (_areaFilter != 'worldwide') count++;
    if (_onlyOnline) count++;
    if (_onlyGold) count++;
    if (_onlyPremium) count++;
    if (_ageRange.start.round() != 18 || _ageRange.end.round() != 99) count++;
    if (_heightRange.start.round() != 100 ||
        _heightRange.end.round() != 250) {
      count++;
    }
    if (_weightRange.start.round() != 35 || _weightRange.end.round() != 200) {
      count++;
    }
    if (_sortMode != ProfileBrowserSortMode.onlineFirst) count++;

    return count;
  }

  int _compareOnlineGoldPremiumUpdated(
    DiscoveryProfile a,
    DiscoveryProfile b,
  ) {
    final onlineCompare = (b.isOnline ? 1 : 0).compareTo(a.isOnline ? 1 : 0);
    if (onlineCompare != 0) return onlineCompare;

    final goldCompare = (b.isGold ? 1 : 0).compareTo(a.isGold ? 1 : 0);
    if (goldCompare != 0) return goldCompare;

    final premiumCompare =
        (b.isPremium ? 1 : 0).compareTo(a.isPremium ? 1 : 0);
    if (premiumCompare != 0) return premiumCompare;

    return _compareDateDesc(a.updatedAt, b.updatedAt);
  }

  int _comparePopularity(DiscoveryProfile a, DiscoveryProfile b) {
    final scoreA = _popularityScore(a);
    final scoreB = _popularityScore(b);

    final scoreCompare = scoreB.compareTo(scoreA);
    if (scoreCompare != 0) return scoreCompare;

    return _compareOnlineGoldPremiumUpdated(a, b);
  }

  int _popularityScore(DiscoveryProfile p) {
    int score = 0;

    if (p.isGold) score += 100;
    if (p.isPremium) score += 50;
    if (p.isOnline) score += 25;
    if ((p.avatarUrl ?? '').trim().isNotEmpty) score += 10;
    if ((p.displayName).trim().isNotEmpty) score += 4;
    if ((p.city ?? '').trim().isNotEmpty) score += 3;
    if ((p.originCountry ?? '').trim().isNotEmpty) score += 3;
    if ((p.job ?? '').trim().isNotEmpty) score += 2;
    if ((p.hobbies ?? '').trim().isNotEmpty) score += 2;
    if (p.languages.isNotEmpty) score += 2;
    if (p.age != null) score += 2;
    if (p.heightCm != null) score += 1;
    if (p.weightKg != null) score += 1;
    if ((p.hairColor ?? '').trim().isNotEmpty) score += 1;
    if ((p.eyeColor ?? '').trim().isNotEmpty) score += 1;

    return score;
  }

  int _compareDateDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  int _compareNullableIntAsc(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int _compareNullableIntDesc(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  Future<void> _openProfile(DiscoveryProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: profile.userId),
      ),
    );

    if (!mounted) return;
    await _loadProfiles();
  }

  Future<void> _openFilters() async {
    String? gender = _gender;
    String? hairColor = _hairColor;
    String? eyeColor = _eyeColor;
    String? country = _country;
    String? originCountry = _originCountry;
    String? province = _province;
    String? desiredPartner = _desiredPartner;
    String areaFilter = _areaFilter;
    bool onlyOnline = _onlyOnline;
    bool onlyGold = _onlyGold;
    bool onlyPremium = _onlyPremium;
    RangeValues ageRange = _ageRange;
    RangeValues heightRange = _heightRange;
    RangeValues weightRange = _weightRange;
    ProfileBrowserSortMode sortMode = _sortMode;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.90,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _filterTitle(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                gender = null;
                                hairColor = null;
                                eyeColor = null;
                                country = null;
                                originCountry = null;
                                province = null;
                                desiredPartner = null;
                                areaFilter = 'worldwide';
                                onlyOnline = false;
                                onlyGold = false;
                                onlyPremium = false;
                                ageRange = const RangeValues(18, 99);
                                heightRange = const RangeValues(100, 250);
                                weightRange = const RangeValues(35, 200);
                                sortMode = ProfileBrowserSortMode.onlineFirst;
                              });
                            },
                            child: Text(_t.clear),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          DropdownButtonFormField<ProfileBrowserSortMode>(
                            value: sortMode,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _sortTitle(),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.sort_rounded),
                            ),
                            items: ProfileBrowserSortMode.values
                                .map(
                                  (mode) => DropdownMenuItem<ProfileBrowserSortMode>(
                                    value: mode,
                                    child: Text(_sortLabel(mode)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() {
                                sortMode = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: onlyOnline,
                            title: Text(
                              _t.isGerman
                                  ? 'Nur Online'
                                  : _t.isThai
                                      ? 'ออนไลน์เท่านั้น'
                                      : 'Online only',
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                onlyOnline = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: onlyGold,
                            title: const Text('Gold'),
                            onChanged: (value) {
                              setSheetState(() {
                                onlyGold = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: onlyPremium,
                            title: const Text('Premium'),
                            onChanged: (value) {
                              setSheetState(() {
                                onlyPremium = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _areaFilterTitle(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: Text(_worldwideLabel()),
                                  selected: areaFilter == 'worldwide',
                                  onSelected: (_) {
                                    setSheetState(() {
                                      areaFilter = 'worldwide';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Thailand'),
                                  selected: areaFilter == 'thailand',
                                  onSelected: (_) {
                                    setSheetState(() {
                                      areaFilter = 'thailand';
                                      country = null;
                                      originCountry = null;
                                      province = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _t.gender,
                            value: gender,
                            items: _genderOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                gender = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _desiredPartnerLabel(),
                            value: desiredPartner,
                            items: _desiredPartnerOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                desiredPartner = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _countryLabel(),
                            value: country,
                            items: _countryOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                country = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _originCountryLabel(),
                            value: originCountry,
                            items: _originCountryOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                originCountry = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _provinceLabel(),
                            value: province,
                            items: _provinceOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                province = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _t.hairColor,
                            value: hairColor,
                            items: _hairColorOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                hairColor = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterDropdown(
                            label: _t.eyeColor,
                            value: eyeColor,
                            items: _eyeColorOptions,
                            allLabel: _allLabel(),
                            onChanged: (value) {
                              setSheetState(() {
                                eyeColor = value;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          _RangeFilterCard(
                            title:
                                '${_t.age}: ${ageRange.start.round()} - ${ageRange.end.round()}',
                            values: ageRange,
                            min: 18,
                            max: 99,
                            divisions: 81,
                            onChanged: (value) {
                              setSheetState(() {
                                ageRange = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _RangeFilterCard(
                            title:
                                '${_t.height}: ${heightRange.start.round()} - ${heightRange.end.round()} cm',
                            values: heightRange,
                            min: 100,
                            max: 250,
                            divisions: 150,
                            onChanged: (value) {
                              setSheetState(() {
                                heightRange = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _RangeFilterCard(
                            title:
                                '${_t.weight}: ${weightRange.start.round()} - ${weightRange.end.round()} kg',
                            values: weightRange,
                            min: 35,
                            max: 200,
                            divisions: 165,
                            onChanged: (value) {
                              setSheetState(() {
                                weightRange = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(_t.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(_t.apply),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    setState(() {
      _gender = gender;
      _hairColor = hairColor;
      _eyeColor = eyeColor;
      _country = country;
      _originCountry = originCountry;
      _province = province;
      _desiredPartner = desiredPartner;
      _areaFilter = areaFilter;
      _onlyOnline = onlyOnline;
      _onlyGold = onlyGold;
      _onlyPremium = onlyPremium;
      _ageRange = ageRange;
      _heightRange = heightRange;
      _weightRange = weightRange;
      _sortMode = sortMode;
    });
  }

  Widget _buildActiveFilterSummary(int profileCount) {
    final activeFilterCount = _activeFilterCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t.isGerman
                  ? '$profileCount Profile • ${_activeFiltersLabel(activeFilterCount)}'
                  : _t.isThai
                      ? '$profileCount โปรไฟล์ • ${_activeFiltersLabel(activeFilterCount)}'
                      : '$profileCount profiles • ${_activeFiltersLabel(activeFilterCount)}',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.66),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(_t.clear),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final profiles = _filteredProfiles;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          IconButton(
            onPressed: _loading ? null : _openFilters,
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text(_activeFilterCount.toString()),
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: _filterTitle(),
          ),
          IconButton(
            onPressed: _loading ? null : _loadProfiles,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: _t.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _searchHint(),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          _buildActiveFilterSummary(profiles.length),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    : profiles.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _emptyText(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadProfiles,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                              itemCount: profiles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final profile = profiles[index];
                                return _ProfileBrowserTile(
                                  profile: profile,
                                  onTap: () => _openProfile(profile),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}


String _localizedGenderLabel(String value, AppStrings t) {
  final normalized = value.trim().toLowerCase();

  if (normalized == 'male') {
    if (t.isGerman) return 'Männlich';
    if (t.isThai) return 'ผู้ชาย';
    return 'Male';
  }

  if (normalized == 'female') {
    if (t.isGerman) return 'Weiblich';
    if (t.isThai) return 'ผู้หญิง';
    return 'Female';
  }

  if (normalized == 'other') {
    if (t.isGerman) return 'Divers';
    if (t.isThai) return 'อื่นๆ';
    return 'Other';
  }

  return value;
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.allLabel,
    required this.onChanged,
  });


  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(allLabel),
        ),
        ...items.map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _RangeFilterCard extends StatelessWidget {
  final String title;
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<RangeValues> onChanged;

  const _RangeFilterCard({
    required this.title,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          RangeSlider(
            values: values,
            min: min,
            max: max,
            divisions: divisions,
            labels: RangeLabels(
              values.start.round().toString(),
              values.end.round().toString(),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfileBrowserTile extends StatelessWidget {
  final DiscoveryProfile profile;
  final VoidCallback onTap;

  const _ProfileBrowserTile({
    required this.profile,
    required this.onTap,
  });

  String _desiredPartnerText(AppStrings t, String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'male':
        if (t.isGerman) return 'Sucht Mann';
        if (t.isThai) return 'มองหาผู้ชาย';
        return 'Looking for male';
      case 'female':
        if (t.isGerman) return 'Sucht Frau';
        if (t.isThai) return 'มองหาผู้หญิง';
        return 'Looking for female';
      case 'transgender':
        if (t.isGerman) return 'Sucht Transgender';
        if (t.isThai) return 'มองหาทรานส์เจนเดอร์';
        return 'Looking for transgender';
      default:
        return raw.trim();
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final name = profile.displayName.trim().isEmpty
        ? (t.isGerman
            ? 'Profil'
            : t.isThai
                ? 'โปรไฟล์'
                : 'Profile')
        : profile.displayName.trim();

    final subtitleParts = <String>[
      if ((profile.city ?? '').trim().isNotEmpty) profile.city!.trim(),
      if ((profile.province ?? '').trim().isNotEmpty) profile.province!.trim(),
      if ((profile.originCountry ?? '').trim().isNotEmpty)
        profile.originCountry!.trim(),
      if (profile.age != null) '${profile.age}',
      if (profile.heightCm != null) '${profile.heightCm} cm',
      if (profile.weightKg != null) '${profile.weightKg} kg',
    ];

    final detailParts = <String>[
      if ((profile.job ?? '').trim().isNotEmpty) profile.job!.trim(),
      if ((profile.hairColor ?? '').trim().isNotEmpty) profile.hairColor!.trim(),
      if ((profile.eyeColor ?? '').trim().isNotEmpty) profile.eyeColor!.trim(),
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: (profile.avatarUrl ?? '').trim().isNotEmpty
                        ? NetworkImage(profile.avatarUrl!.trim())
                        : null,
                    child: (profile.avatarUrl ?? '').trim().isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: profile.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.isEmpty
                          ? (t.isGerman
                              ? 'Profil ansehen'
                              : t.isThai
                                  ? 'ดูโปรไฟล์'
                                  : 'View profile')
                          : subtitleParts.join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detailParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detailParts.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.50),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(
                          text: profile.isOnline
                              ? (t.isGerman
                                  ? 'Online'
                                  : t.isThai
                                      ? 'ออนไลน์'
                                      : 'Online')
                              : (t.isGerman
                                  ? 'Offline'
                                  : t.isThai
                                      ? 'ออฟไลน์'
                                      : 'Offline'),
                          color: profile.isOnline ? Colors.green : Colors.grey,
                        ),
                        if (profile.isGold)
                          const _MiniBadge(text: 'Gold', color: Colors.amber),
                        if (!profile.isGold && profile.isPremium)
                          const _MiniBadge(text: 'Premium', color: Colors.pink),
                        if ((profile.gender ?? '').trim().isNotEmpty)
                          _MiniBadge(
                            text: profile.gender!.trim(),
                            color: Colors.blueGrey,
                          ),
                        if ((profile.desiredPartner ?? '').trim().isNotEmpty)
                          _MiniBadge(
                            text: _desiredPartnerText(
                              t,
                              profile.desiredPartner!.trim(),
                            ),
                            color: Colors.deepPurple,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({
    required this.text,
    required this.color,
  });


  @override
  Widget build(BuildContext context) {
    final fg = color == Colors.amber ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == Colors.amber ? 0.9 : 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}