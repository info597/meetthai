import 'package:supabase_flutter/supabase_flutter.dart';

/// Modell für das eigene Profil (für Home / Profil bearbeiten)
class UserProfile {
  final String userId;
  final String displayName;
  final String? gender;
  final String? originCountry;
  final String? state;
  final String? region;
  final String? city;
  final String? job;
  final List<String> languages;
  final List<String> hobbies;
  final String? bio;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.userId,
    required this.displayName,
    this.gender,
    this.originCountry,
    this.state,
    this.region,
    this.city,
    this.job,
    this.languages = const [],
    this.hobbies = const [],
    this.bio,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['user_id'] as String,
      displayName: (map['display_name'] ?? '') as String,
      gender: map['gender'] as String?,
      originCountry: map['origin_country'] as String?,
      state: map['state'] as String?,
      region: map['region'] as String?,
      city: map['city'] as String?,
      job: map['job'] as String?,
      languages: (map['languages'] is List)
          ? (map['languages'] as List).cast<String>()
          : const [],
      hobbies: (map['hobbies'] is List)
          ? (map['hobbies'] as List).cast<String>()
          : const [],
      bio: map['bio'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isOnline: (map['is_online'] ?? false) as bool,
      lastSeen: map['last_seen'] != null
          ? DateTime.tryParse(map['last_seen'] as String)
          : null,
    );
  }
}

class ProfileService {
  static final _supa = Supabase.instance.client;

  /// Holt das Profil des aktuell eingeloggten Users.
  static Future<UserProfile?> loadCurrentUserProfile() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await _supa
        .from('profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

    if (data == null) return null;

    return UserProfile.fromMap(data as Map<String, dynamic>);
  }

  /// Speichert / upsert das Profil des aktuellen Users.
  ///
  /// ⚠️ WICHTIG:
  ///  - KEIN onConflict mehr → dadurch verschwindet der 400-Fehler
  ///  - wir schicken nur Spalten, die es (bei dir) gibt
  static Future<void> saveCurrentUserProfile({
    required String displayName,
    String? gender,
    String? originCountry,
    String? state,
    String? region,
    String? city,
    String? job,
    List<String>? languages,
    List<String>? hobbies,
    String? bio,
    String? avatarUrl,
  }) async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      throw Exception('Nicht eingeloggt – Profil kann nicht gespeichert werden.');
    }

    // Payload bauen – nur bekannte Spalten
    final payload = <String, dynamic>{
      'user_id': user.id, // FK zu auth.users
      'display_name': displayName,
      'gender': gender,
      'origin_country': originCountry,
      'state': state,
      'region': region,
      'city': city,
      'job': job,
      'languages': languages ?? <String>[],
      'hobbies': hobbies ?? <String>[],
      'bio': bio,
      'avatar_url': avatarUrl,
      // is_online & last_seen machst du separat via RPC / Ping
      'updated_at': DateTime.now().toIso8601String(),
    };

    // NULL-Werte entfernen, damit PostgREST nicht meckert
    payload.removeWhere((key, value) => value == null);

    try {
      // WICHTIG: kein onConflict hier!
      await _supa
          .from('profiles')
          .upsert(payload)
          .select()
          .maybeSingle();
    } on PostgrestException catch (e) {
      // Damit du den Fehlertext sauber in der Snackbar siehst
      throw Exception('Supabase-Fehler: ${e.message}');
    } catch (e) {
      throw Exception('Unerwarteter Fehler beim Speichern: $e');
    }
  }

  /// Optional: Online-Status / last_seen updaten
  static Future<void> pingOnline() async {
    try {
      await _supa.rpc('update_last_seen');
    } catch (_) {
      // Ignorieren – ist nur ein Komfort-Feature
    }
  }
}
