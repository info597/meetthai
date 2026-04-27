// lib/services/photo_moderation_service.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Ergebnis der Moderation
class PhotoModerationResult {
  final bool isAllowed;
  final double nudityScore;
  final String reason;

  PhotoModerationResult({
    required this.isAllowed,
    required this.nudityScore,
    required this.reason,
  });
}

class PhotoModerationService {
  static final SupabaseClient _supa = Supabase.instance.client;

  /// 🔍 Hauptfunktion: prüft Bild über Supabase Edge Function
  static Future<PhotoModerationResult> checkImage(
    Uint8List imageBytes,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final response = await _supa.functions.invoke(
        'moderate-photo',
        body: {
          'media': base64Image,
        },
      );

      /// 🔥 Debug (sehr wichtig aktuell)
      print('MODERATION RESPONSE: ${response.data}');

      final data = response.data;

      if (data is! Map) {
        return PhotoModerationResult(
          isAllowed: false,
          nudityScore: 1.0,
          reason: 'Invalid moderation response',
        );
      }

      final allowed = data['allowed'] == true;
      final nudityScoreRaw = data['nudityScore'];
      final reason = (data['reason'] ?? 'Unknown').toString();

      final nudityScore = nudityScoreRaw is num
          ? nudityScoreRaw.toDouble()
          : 0.0;

      return PhotoModerationResult(
        isAllowed: allowed,
        nudityScore: nudityScore,
        reason: reason,
      );
    } catch (e) {
      print('MODERATION ERROR: $e');

      return PhotoModerationResult(
        isAllowed: false,
        nudityScore: 1.0,
        reason: 'Moderation failed: $e',
      );
    }
  }
}