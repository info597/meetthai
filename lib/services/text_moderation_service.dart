import 'package:supabase_flutter/supabase_flutter.dart';

class TextModerationResult {
  final bool isAllowed;
  final String reason;

  TextModerationResult({
    required this.isAllowed,
    required this.reason,
  });
}

class TextModerationService {
  static final SupabaseClient _supa = Supabase.instance.client;

  static Future<TextModerationResult> checkTexts(
    List<String> texts,
  ) async {
    try {
      final cleanedTexts = texts
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (cleanedTexts.isEmpty) {
        return TextModerationResult(
          isAllowed: true,
          reason: 'Empty text allowed',
        );
      }

      final response = await _supa.functions.invoke(
        'moderate-profile-text',
        body: {
          'texts': cleanedTexts,
        },
      );

      final data = response.data;

      if (data is! Map) {
        return TextModerationResult(
          isAllowed: false,
          reason: 'Invalid moderation response',
        );
      }

      final allowed = data['allowed'] == true;
      final reason = (data['reason'] ?? 'Unknown').toString();

      return TextModerationResult(
        isAllowed: allowed,
        reason: reason,
      );
    } catch (e) {
      return TextModerationResult(
        isAllowed: false,
        reason: 'Text moderation failed: $e',
      );
    }
  }
}