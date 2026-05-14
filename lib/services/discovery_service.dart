import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoveryProfile {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? city;
  final String? country;
  final String? province;
  final String? originCountry;
  final String? job;
  final bool isOnline;
  final bool isGold;
  final bool isPremium;
  final String? desiredPartner;
  final String? hobbies;
  final List<String> languages;

  final String? gender;
  final DateTime? birthdate;
  final int? heightCm;
  final int? weightKg;
  final String? hairColor;
  final String? eyeColor;
  final String? religion;
  final DateTime? updatedAt;
  final DateTime? lastSeen;

  final double? latitude;
  final double? longitude;

  const DiscoveryProfile({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.country,
    required this.province,
    required this.originCountry,
    required this.job,
    required this.isOnline,
    required this.isGold,
    required this.isPremium,
    required this.desiredPartner,
    required this.hobbies,
    required this.languages,
    required this.gender,
      lastSeenAt,
    required this.birthdate,
    required this.heightCm,
    required this.weightKg,
    required this.hairColor,
    required this.eyeColor,
    required this.religion,
    required this.updatedAt,
    required this.lastSeen,
    required this.latitude,
    required this.longitude,
  });

  int? get age {
    final date = birthdate;
    if (date == null) return null;

    final now = DateTime.now();
    int calculated = now.year - date.year;

    final hadBirthday = now.month > date.month ||
        (now.month == date.month && now.day >= date.day);

    if (!hadBirthday) {
      calculated--;
    }

    if (calculated < 0 || calculated > 120) return null;
    return calculated;
  }

  factory DiscoveryProfile.fromRow(Map<String, dynamic> row) {
    final planCode = (row['plan_code'] ?? '').toString().trim().toLowerCase();
    final rawIsGold = row['is_gold'] == true;
    final rawIsPremium = row['is_premium'] == true;

    final normalizedIsGold = rawIsGold || planCode == 'gold';
    final normalizedIsPremium =
        normalizedIsGold || rawIsPremium || planCode == 'premium';

    final parsedLanguages = <String>[];
    final rawLanguages = row['languages'];

    if (rawLanguages is List) {
      for (final item in rawLanguages) {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          parsedLanguages.add(value);
        }
      }
    }

    String? hobbiesText;
    final rawHobbies = row['hobbies'];
    if (rawHobbies is List) {
      final values = rawHobbies
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      hobbiesText = values.isEmpty ? null : values.join(', ');
    } else {
      final text = rawHobbies?.toString().trim();
      hobbiesText = (text == null || text.isEmpty) ? null : text;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return DiscoveryProfile(
      userId: row['user_id'].toString(),
      displayName: (row['display_name'] ?? '').toString().trim(),
      avatarUrl: row['avatar_url']?.toString(),
      city: row['city']?.toString(),
      country: row['country']?.toString(),
      province: row['province']?.toString(),
      originCountry: row['origin_country']?.toString(),
      job: row['job']?.toString(),
      isOnline: row['is_online'] == true,
      isGold: normalizedIsGold,
      isPremium: normalizedIsPremium,
      desiredPartner: row['desired_partner']?.toString(),
      hobbies: hobbiesText,
      languages: parsedLanguages,
      gender: row['gender']?.toString(),
      birthdate: parseDate(row['birthdate']),
      heightCm: parseInt(row['height_cm']),
      weightKg: parseInt(row['weight_kg']),
      hairColor: row['hair_color']?.toString(),
      eyeColor: row['eye_color']?.toString(),
      religion: row['religion']?.toString(),
      updatedAt: parseDate(row['updated_at']),
      lastSeen: parseDate(row['last_seen']),
      latitude: parseDouble(row['latitude']),
      longitude: parseDouble(row['longitude']),
    );
  }
}

class _MyGeoSearchSettings {
  final double searchRadiusKm;
  final double? latitude;
  final double? longitude;

  const _MyGeoSearchSettings({
    required this.searchRadiusKm,
    required this.latitude,
    required this.longitude,
  });

  bool get isWorldwide => searchRadiusKm >= DiscoveryService.worldwideRadiusKm;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class PreferredPartnerFilters {
  final double searchRadiusKm;
  final String? desiredPartner;
  final int preferredAgeMin;
  final int preferredAgeMax;
  final int preferredHeightMin;
  final int preferredHeightMax;
  final String? preferredHairColor;
  final String? preferredEyeColor;
  final String? preferredReligion;
  final String? preferredOriginCountry;
  final String? preferredCountry;
  final String? preferredProvince;

  const PreferredPartnerFilters({
    required this.searchRadiusKm,
    required this.desiredPartner,
    required this.preferredAgeMin,
    required this.preferredAgeMax,
    required this.preferredHeightMin,
    required this.preferredHeightMax,
    required this.preferredHairColor,
    required this.preferredEyeColor,
    required this.preferredReligion,
    required this.preferredOriginCountry,
    required this.preferredCountry,
    required this.preferredProvince,
  });

  static const fallback = PreferredPartnerFilters(
    searchRadiusKm: 50,
    desiredPartner: null,
    preferredAgeMin: 18,
    preferredAgeMax: 99,
    preferredHeightMin: 100,
    preferredHeightMax: 250,
    preferredHairColor: null,
    preferredEyeColor: null,
    preferredReligion: null,
    preferredOriginCountry: null,
    preferredCountry: null,
    preferredProvince: null,
  );
}

class DiscoveryService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static const double thailandRadiusKm = 2500;
  static const double worldwideRadiusKm = 50000;

  static String _requireUserId() {
    final user = _supa.auth.currentUser;
    if (user == null) {
      throw Exception('Nicht eingeloggt.');
    }
    return user.id;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static String? _cleanString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static Future<PreferredPartnerFilters> loadMyPreferredPartnerFilters() async {
    final me = _requireUserId();

    try {
      final row = await _supa
          .from('profiles')
          .select('''
            search_radius_km,
            desired_partner,
            preferred_age_min,
            preferred_age_max,
            preferred_height_min,
            preferred_height_max,
            preferred_hair_color,
            preferred_eye_color,
            preferred_religion,
            preferred_origin_country,
            preferred_country,
            preferred_province
          ''')
          .eq('user_id', me)
          .maybeSingle();

      return PreferredPartnerFilters(
        searchRadiusKm:
            _parseDouble(row?['search_radius_km']) ?? PreferredPartnerFilters.fallback.searchRadiusKm,
        desiredPartner: _cleanString(row?['desired_partner']),
        preferredAgeMin:
            _parseInt(row?['preferred_age_min']) ?? PreferredPartnerFilters.fallback.preferredAgeMin,
        preferredAgeMax:
            _parseInt(row?['preferred_age_max']) ?? PreferredPartnerFilters.fallback.preferredAgeMax,
        preferredHeightMin:
            _parseInt(row?['preferred_height_min']) ?? PreferredPartnerFilters.fallback.preferredHeightMin,
        preferredHeightMax:
            _parseInt(row?['preferred_height_max']) ?? PreferredPartnerFilters.fallback.preferredHeightMax,
        preferredHairColor: _cleanString(row?['preferred_hair_color']),
        preferredEyeColor: _cleanString(row?['preferred_eye_color']),
        preferredReligion: _cleanString(row?['preferred_religion']),
        preferredOriginCountry: _cleanString(row?['preferred_origin_country']),
        preferredCountry: _cleanString(row?['preferred_country']),
        preferredProvince: _cleanString(row?['preferred_province']),
      );
    } catch (_) {
      try {
        final row = await _supa
            .from('profiles')
            .select('''
              search_radius_km,
              desired_partner,
              preferred_age_min,
              preferred_age_max,
              preferred_height_min,
              preferred_height_max,
              preferred_hair_color,
              preferred_origin_country
            ''')
            .eq('user_id', me)
            .maybeSingle();

        return PreferredPartnerFilters(
          searchRadiusKm:
              _parseDouble(row?['search_radius_km']) ?? PreferredPartnerFilters.fallback.searchRadiusKm,
          desiredPartner: _cleanString(row?['desired_partner']),
          preferredAgeMin:
              _parseInt(row?['preferred_age_min']) ?? PreferredPartnerFilters.fallback.preferredAgeMin,
          preferredAgeMax:
              _parseInt(row?['preferred_age_max']) ?? PreferredPartnerFilters.fallback.preferredAgeMax,
          preferredHeightMin:
              _parseInt(row?['preferred_height_min']) ?? PreferredPartnerFilters.fallback.preferredHeightMin,
          preferredHeightMax:
              _parseInt(row?['preferred_height_max']) ?? PreferredPartnerFilters.fallback.preferredHeightMax,
          preferredHairColor: _cleanString(row?['preferred_hair_color']),
          preferredEyeColor: null,
          preferredReligion: null,
          preferredOriginCountry: _cleanString(row?['preferred_origin_country']),
          preferredCountry: null,
          preferredProvince: null,
        );
      } catch (_) {
        return PreferredPartnerFilters.fallback;
      }
    }
  }

  static double _distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final rLat1 = _degreesToRadians(lat1);
    final rLat2 = _degreesToRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  static Future<void> pingOnline() async {
    final me = _supa.auth.currentUser;
    if (me == null) return;

    try {
      await _supa.from('profiles').update({
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('user_id', me.id);
    } catch (_) {}
  }

  static Future<_MyGeoSearchSettings> _loadMyGeoSearchSettings(
    String me,
  ) async {
    try {
      final row = await _supa
          .from('profiles')
          .select('search_radius_km, latitude, longitude')
          .eq('user_id', me)
          .maybeSingle();

      final radius = _parseDouble(row?['search_radius_km']) ?? 50;
      final latitude = _parseDouble(row?['latitude']);
      final longitude = _parseDouble(row?['longitude']);

      return _MyGeoSearchSettings(
        searchRadiusKm: radius,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      try {
        final row = await _supa
            .from('profiles')
            .select('search_radius_km')
            .eq('user_id', me)
            .maybeSingle();

        final radius = _parseDouble(row?['search_radius_km']) ?? 50;

        return _MyGeoSearchSettings(
          searchRadiusKm: radius,
          latitude: null,
          longitude: null,
        );
      } catch (_) {
        return const _MyGeoSearchSettings(
          searchRadiusKm: 50,
          latitude: null,
          longitude: null,
        );
      }
    }
  }

  static Future<Set<String>> _loadBlockedUserIds(String me) async {
    final blocked = <String>{};

    final rows = await _supa
        .from('user_blocks')
        .select('blocker_user_id, blocked_user_id')
        .or('blocker_user_id.eq.$me,blocked_user_id.eq.$me');

    for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
      final blocker = raw['blocker_user_id']?.toString();
      final blockedUser = raw['blocked_user_id']?.toString();

      if (blocker == null || blockedUser == null) continue;

      if (blocker == me) {
        blocked.add(blockedUser);
      } else if (blockedUser == me) {
        blocked.add(blocker);
      }
    }

    return blocked;
  }

  static Future<Set<String>> _loadMatchedUserIds(String me) async {
    final matched = <String>{};

    final rows = await _supa
        .from('matches')
        .select('user_a, user_b')
        .or('user_a.eq.$me,user_b.eq.$me');

    for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
      final a = raw['user_a']?.toString();
      final b = raw['user_b']?.toString();

      if (a == null || b == null) continue;

      matched.add(a == me ? b : a);
    }

    return matched;
  }

  static Future<Set<String>> _loadAlreadyLikedUserIds(String me) async {
    final liked = <String>{};

    final rows =
        await _supa.from('likes').select('to_user_id').eq('from_user_id', me);

    for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
      final toUserId = raw['to_user_id']?.toString();
      if (toUserId != null && toUserId.isNotEmpty) {
        liked.add(toUserId);
      }
    }

    return liked;
  }

  static Future<Set<String>> _loadDeletedUserIds() async {
    try {
      final rows =
          await _supa.from('profiles').select('user_id').eq('is_deleted', true);

      return (rows as List)
          .map((row) => (row['user_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      try {
        final rows = await _supa
            .from('profiles')
            .select('user_id')
            .not('deleted_at', 'is', null);

        return (rows as List)
            .map((row) => (row['user_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        return <String>{};
      }
    }
  }

  static String get _profileSelectColumns => '''
          user_id,
          display_name,
          avatar_url,
          city,
          country,
          province,
          origin_country,
          job,
          is_online,
          is_gold,
          is_premium,
          plan_code,
          is_hidden,
          is_deleted,
          deleted_at,
          updated_at,
          last_seen,
          desired_partner,
          hobbies,
          languages,
          gender,
          birthdate,
          height_cm,
          weight_kg,
          hair_color,
          eye_color,
          religion
        ''';

  static String get _profileSelectColumnsWithGeo => '''
          user_id,
          display_name,
          avatar_url,
          city,
          country,
          province,
          origin_country,
          job,
          is_online,
          is_gold,
          is_premium,
          plan_code,
          is_hidden,
          is_deleted,
          deleted_at,
          updated_at,
          last_seen,
          desired_partner,
          hobbies,
          languages,
          gender,
          birthdate,
          height_cm,
          weight_kg,
          hair_color,
          eye_color,
          religion,
          latitude,
          longitude
        ''';

  static Future<List<Map<String, dynamic>>> _loadProfileRows({
    required String me,
    required int limit,
    required bool discoveryOrder,
  }) async {
    try {
      var query = _supa
          .from('profiles')
          .select(_profileSelectColumnsWithGeo)
          .neq('user_id', me)
          .eq('is_hidden', false);

      if (discoveryOrder) {
        final rows = await query
            .order('is_gold', ascending: false)
            .order('is_premium', ascending: false)
            .order('updated_at', ascending: false)
            .limit(limit);

        return (rows as List).cast<Map<String, dynamic>>();
      }

      final rows = await query
          .order('is_online', ascending: false)
          .order('is_gold', ascending: false)
          .order('is_premium', ascending: false)
          .order('updated_at', ascending: false)
          .limit(limit);

      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      var query = _supa
          .from('profiles')
          .select(_profileSelectColumns)
          .neq('user_id', me)
          .eq('is_hidden', false);

      if (discoveryOrder) {
        final rows = await query
            .order('is_gold', ascending: false)
            .order('is_premium', ascending: false)
            .order('updated_at', ascending: false)
            .limit(limit);

        return (rows as List).cast<Map<String, dynamic>>();
      }

      final rows = await query
          .order('is_online', ascending: false)
          .order('is_gold', ascending: false)
          .order('is_premium', ascending: false)
          .order('updated_at', ascending: false)
          .limit(limit);

      return (rows as List).cast<Map<String, dynamic>>();
    }
  }

  static bool _isThailandProfile(DiscoveryProfile profile) {
    final values = [
      profile.country,
      profile.originCountry,
      profile.province,
      profile.city,
    ];

    return values.whereType<String>().any((value) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'thailand' ||
          normalized == 'thai' ||
          normalized == 'ไทย' ||
          normalized == 'ประเทศไทย' ||
          normalized.contains('thailand');
    });
  }

  static bool _isInsideSearchRadius({
    required _MyGeoSearchSettings settings,
    required DiscoveryProfile profile,
  }) {
    if (settings.isWorldwide) return true;

    if (!settings.hasCoordinates) {
      return true;
    }

    final myLat = settings.latitude;
    final myLon = settings.longitude;
    final otherLat = profile.latitude;
    final otherLon = profile.longitude;

    if (myLat == null || myLon == null || otherLat == null || otherLon == null) {
      return true;
    }

    final distance = _distanceKm(
      lat1: myLat,
      lon1: myLon,
      lat2: otherLat,
      lon2: otherLon,
    );

    return distance <= settings.searchRadiusKm;
  }

  static Future<List<DiscoveryProfile>> loadDiscoveryProfiles({
    int limit = 30,
    bool excludeAlreadyLiked = true,
    bool thailandOnly = false,
    bool worldwide = false,
  }) async {
    final me = _requireUserId();

    debugPrint('DISCOVERY me=$me');

    final settings = await _loadMyGeoSearchSettings(me);
    final blockedIds = await _loadBlockedUserIds(me);
    final matchedIds = await _loadMatchedUserIds(me);
    final likedIds =
        excludeAlreadyLiked ? await _loadAlreadyLikedUserIds(me) : <String>{};
    final deletedIds = await _loadDeletedUserIds();

    debugPrint('DISCOVERY radiusKm=${settings.searchRadiusKm}');
    debugPrint('DISCOVERY isWorldwide=${settings.isWorldwide}');
    debugPrint('DISCOVERY hasCoordinates=${settings.hasCoordinates}');
    debugPrint('DISCOVERY blockedIds=$blockedIds');
    debugPrint('DISCOVERY matchedIds=$matchedIds');
    debugPrint('DISCOVERY likedIds=$likedIds');
    debugPrint('DISCOVERY deletedIds=$deletedIds');

    final useThailandOnly = thailandOnly ||
        (settings.searchRadiusKm >= thailandRadiusKm &&
            settings.searchRadiusKm < worldwideRadiusKm);
    final useWorldwide = worldwide || settings.isWorldwide;

    final rows = await _loadProfileRows(
      me: me,
      limit: limit * 8,
      discoveryOrder: true,
    );

    debugPrint('DISCOVERY raw rows count=${rows.length}');

    final out = <DiscoveryProfile>[];

    for (final raw in rows) {
      final userId = raw['user_id']?.toString();
      final displayName = raw['display_name']?.toString();
      final isDeleted = raw['is_deleted'] == true;
      final hasDeletedAt = raw['deleted_at'] != null;

      debugPrint('DISCOVERY raw profile userId=$userId displayName=$displayName');

      if (userId == null || userId.isEmpty) continue;
      if (isDeleted || hasDeletedAt) {
        debugPrint('DISCOVERY skip deleted flag $userId');
        continue;
      }
      if (deletedIds.contains(userId)) {
        debugPrint('DISCOVERY skip deleted set $userId');
        continue;
      }
      if (blockedIds.contains(userId)) {
        debugPrint('DISCOVERY skip blocked $userId');
        continue;
      }
      if (matchedIds.contains(userId)) {
        debugPrint('DISCOVERY skip matched $userId');
        continue;
      }
      if (likedIds.contains(userId)) {
        debugPrint('DISCOVERY skip liked $userId');
        continue;
      }

      final profile = DiscoveryProfile.fromRow(raw);

      if (useThailandOnly && !_isThailandProfile(profile)) {
        debugPrint('DISCOVERY skip outside thailand $userId');
        continue;
      }

      if (!useThailandOnly &&
          !useWorldwide &&
          !_isInsideSearchRadius(
            settings: settings,
            profile: profile,
          )) {
        debugPrint('DISCOVERY skip outside radius $userId');
        continue;
      }

      out.add(profile);
      debugPrint('DISCOVERY add profile $userId');

      if (out.length >= limit) break;
    }

    debugPrint('DISCOVERY final result count=${out.length}');
    return out;
  }

  static Future<List<DiscoveryProfile>> loadBrowseProfiles({
    int limit = 250,
    double? searchRadiusKmOverride,
    bool thailandOnly = false,
    bool worldwide = false,
  }) async {
    final me = _requireUserId();

    final savedSettings = await _loadMyGeoSearchSettings(me);
    final settings = searchRadiusKmOverride == null
        ? savedSettings
        : _MyGeoSearchSettings(
            searchRadiusKm: searchRadiusKmOverride,
            latitude: savedSettings.latitude,
            longitude: savedSettings.longitude,
          );
    final blockedIds = await _loadBlockedUserIds(me);
    final deletedIds = await _loadDeletedUserIds();

    // Mitglieder/Browse: Thailand darf nur greifen, wenn der Filter explizit aktiv ist.
    // Sonst wurden bei "Keine Filter aktiv" trotzdem nur Thailand-Profile gezeigt,
    // sobald im Profil ein großer Radius gespeichert war.
    final useThailandOnly = thailandOnly;
    final useWorldwide = worldwide || !thailandOnly || settings.isWorldwide;

    final rows = await _loadProfileRows(
      me: me,
      limit: limit * 4,
      discoveryOrder: false,
    );

    final out = <DiscoveryProfile>[];

    for (final raw in rows) {
      final userId = raw['user_id']?.toString();
      final isDeleted = raw['is_deleted'] == true;
      final hasDeletedAt = raw['deleted_at'] != null;

      if (userId == null || userId.isEmpty) continue;
      if (isDeleted || hasDeletedAt) continue;
      if (deletedIds.contains(userId)) continue;
      if (blockedIds.contains(userId)) continue;

      final profile = DiscoveryProfile.fromRow(raw);

      if (useThailandOnly && !_isThailandProfile(profile)) {
        continue;
      }

      if (!useThailandOnly &&
          !useWorldwide &&
          !_isInsideSearchRadius(
            settings: settings,
            profile: profile,
          )) {
        continue;
      }

      out.add(profile);

      if (out.length >= limit) break;
    }

    return out;
  }
}