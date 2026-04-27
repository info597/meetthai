// lib/services/profile_photos_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePhoto {
  /// WICHTIG: für consume_photo_view RPC
  final String id;

  final String fullUrl;
  final String? blurUrl;
  final int sortIndex;

  ProfilePhoto({
    required this.id,
    required this.fullUrl,
    required this.sortIndex,
    this.blurUrl,
  });

  factory ProfilePhoto.fromMap(Map<String, dynamic> map) {
    return ProfilePhoto(
      id: (map['id'] ?? '').toString(),
      fullUrl: (map['full_url'] ?? '') as String,
      blurUrl: map['blur_url'] as String?,
      sortIndex: (map['sort_index'] ?? 0) as int,
    );
  }
}

class ProfilePhotosService {
  static final _supa = Supabase.instance.client;

  /// Lädt alle Fotos eines Users (ohne Limit-Logik).
  /// Limit/Blur-Logik passiert in ProfilePhotosGallery.
  static Future<List<ProfilePhoto>> loadPhotosForUser(String userId) async {
    final res = await _supa
        .from('profile_photos')
        .select('id, full_url, blur_url, sort_index')
        .eq('user_id', userId)
        .order('sort_index', ascending: true)
        .order('created_at', ascending: true);

    final list = (res as List).cast<Map<String, dynamic>>();

    return list
        .map(ProfilePhoto.fromMap)
        .where((p) => p.id.isNotEmpty && p.fullUrl.isNotEmpty)
        .toList();
  }
}