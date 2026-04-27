import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/app_strings.dart';
import 'services/access_service.dart';
import 'services/photo_moderation_service.dart';
import 'services/profile_photos_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _bucket = 'profile-photos';

  final _formKey = GlobalKey<FormState>();

  final _displayNameCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _otherJobCtrl = TextEditingController();
  final _originCountryCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _hobbiesCustomCtrl = TextEditingController();

  final _preferredOriginCountryCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSavingProfile = false;

  String? _avatarUrl;
  List<ProfilePhoto> _photos = [];

  int _remainingSlots = AccessService.maxUploadPhotosPerProfile;

  String? _selectedGender;
  String? _selectedJobCategory;
  String? _selectedEthnicity;
  String? _selectedCountry;
  String? _selectedZodiacSign;
  String? _selectedSmokingStatus;
  String? _selectedHairColor;
  String? _selectedEyeColor;
  String? _selectedBodyType;
  String? _selectedDesiredPartner;

  String? _selectedPreferredHairColor;

  DateTime? _birthDate;
  bool _showPostalCode = false;

  double _preferredAgeMin = 18;
  double _preferredAgeMax = 60;

  double _preferredHeightMin = 140;
  double _preferredHeightMax = 210;

  double _searchRadiusKm = 50;

  final Set<String> _selectedLanguages = <String>{};
  final Set<String> _selectedHobbies = <String>{};

  static const List<String> _genderOptions = [
    'Männlich',
    'Weiblich',
    'Ladyboy',
    'Divers',
  ];

  static const List<String> _desiredPartnerOptions = [
    'Male',
    'Female',
    'Transgender',
  ];

  static const List<String> _jobOptions = [
    'Freelancer',
    'Angestellte/r',
    'Selbstständig',
    'Unternehmer/in',
    'Manager/in',
    'Verkauf',
    'Marketing',
    'IT',
    'Programmierer/in',
    'Designer/in',
    'Lehrer/in',
    'Student/in',
    'Ärztin/Arzt',
    'Krankenpflege',
    'Tourismus',
    'Hotel/Gastro',
    'Model',
    'Influencer',
    'Beauty',
    'Fitness',
    'Behörde',
    'Transport/Logistik',
    'Handwerk',
    'Finanzen',
    'Kundenservice',
    'Produktion',
    'Immobilien',
    'Beratung',
    'Kunst/Musik',
    'Sonstiges',
  ];

  static const List<String> _languageOptions = [
    'Deutsch',
    'Englisch',
    'Thai',
    'Französisch',
    'Italienisch',
    'Spanisch',
    'Portugiesisch',
    'Russisch',
    'Arabisch',
    'Türkisch',
    'Hindi',
    'Urdu',
    'Chinesisch',
    'Japanisch',
    'Koreanisch',
    'Niederländisch',
    'Polnisch',
    'Tschechisch',
    'Slowakisch',
    'Ungarisch',
    'Rumänisch',
    'Bulgarisch',
    'Khmer',
    'Vietnamesisch',
    'Indonesisch',
    'Malaiisch',
    'Tagalog',
    'Laotisch',
    'Birmanisch',
  ];

  static const List<String> _hobbyOptions = [
    'Reisen',
    'Musik',
    'Kochen',
    'Fitness',
    'Gym',
    'Schwimmen',
    'Yoga',
    'Tanzen',
    'Lesen',
    'Filme',
    'Serien',
    'Fotografie',
    'Gaming',
    'Natur',
    'Wandern',
    'Shopping',
    'Karaoke',
    'Motorrad',
    'Autos',
    'Kunst',
    'Mode',
    'Beauty',
    'Meditation',
    'Tiere',
    'Strand',
    'Café',
    'Nachtleben',
    'Volleyball',
    'Badminton',
    'Fußball',
    'Basketball',
  ];

  static const List<String> _ethnicityOptions = [
    'Asian',
    'Caucasian',
    'Black',
    'Latina/Latino',
    'Middle Eastern',
    'Indian',
    'Mixed',
    'Pacific Islander',
    'Andere',
  ];

  static const List<String> _countryOptions = [
    'Thailand',
    'Österreich',
    'Deutschland',
    'Schweiz',
    'Frankreich',
    'Italien',
    'Spanien',
    'Portugal',
    'Niederlande',
    'Belgien',
    'Luxemburg',
    'Großbritannien',
    'Irland',
    'Schweden',
    'Norwegen',
    'Finnland',
    'Dänemark',
    'Polen',
    'Tschechien',
    'Slowakei',
    'Ungarn',
    'Rumänien',
    'Bulgarien',
    'Kroatien',
    'Serbien',
    'Bosnien und Herzegowina',
    'Slowenien',
    'Griechenland',
    'Türkei',
    'Ukraine',
    'Russland',
    'USA',
    'Kanada',
    'Mexiko',
    'Brasilien',
    'Argentinien',
    'Chile',
    'Kolumbien',
    'Peru',
    'Australien',
    'Neuseeland',
    'Japan',
    'Südkorea',
    'China',
    'Taiwan',
    'Hongkong',
    'Singapur',
    'Malaysia',
    'Indonesien',
    'Philippinen',
    'Vietnam',
    'Kambodscha',
    'Laos',
    'Myanmar',
    'Indien',
    'Pakistan',
    'Sri Lanka',
    'Nepal',
    'Bangladesch',
    'Vereinigte Arabische Emirate',
    'Saudi-Arabien',
    'Katar',
    'Südafrika',
    'Ägypten',
    'Marokko',
    'Tunesien',
    'Nigeria',
    'Kenia',
  ];

  static const List<String> _zodiacOptions = [
    'Widder',
    'Stier',
    'Zwillinge',
    'Krebs',
    'Löwe',
    'Jungfrau',
    'Waage',
    'Skorpion',
    'Schütze',
    'Steinbock',
    'Wassermann',
    'Fische',
  ];

  static const List<String> _smokingOptions = [
    'Nichtraucher',
    'Gelegenheitsraucher',
    'Raucher',
    'Starker Raucher',
  ];

  static const List<String> _hairColorOptions = [
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

  static const List<String> _eyeColorOptions = [
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

  static const List<String> _bodyTypeOptions = [
    'Schlank',
    'Sportlich',
    'Normal',
    'Athletisch',
    'Kurvig',
    'Mollig',
    'Kräftig',
  ];

  AppStrings get _t => AppStrings.of(context);

  String get _preferredAgeLabel {
    if (_t.isGerman) {
      return 'Bevorzugtes Alter: ${_preferredAgeMin.round()} - ${_preferredAgeMax.round()}';
    }
    if (_t.isThai) {
      return 'อายุที่ต้องการ: ${_preferredAgeMin.round()} - ${_preferredAgeMax.round()}';
    }
    return 'Preferred age: ${_preferredAgeMin.round()} - ${_preferredAgeMax.round()}';
  }

  String get _preferredHeightLabel {
    if (_t.isGerman) {
      return 'Bevorzugte Größe: ${_preferredHeightMin.round()} - ${_preferredHeightMax.round()} cm';
    }
    if (_t.isThai) {
      return 'ส่วนสูงที่ต้องการ: ${_preferredHeightMin.round()} - ${_preferredHeightMax.round()} ซม.';
    }
    return 'Preferred height: ${_preferredHeightMin.round()} - ${_preferredHeightMax.round()} cm';
  }

  String get _searchRadiusLabel {
    if (_t.isGerman) {
      return 'Suchradius: ${_searchRadiusKm.round()} km';
    }
    if (_t.isThai) {
      return 'ระยะค้นหา: ${_searchRadiusKm.round()} กม.';
    }
    return 'Search radius: ${_searchRadiusKm.round()} km';
  }

  String get _preferredPartnerSectionTitle {
    if (_t.isGerman) return 'Wunschpartner & Suche';
    if (_t.isThai) return 'คู่ที่ต้องการและการค้นหา';
    return 'Preferred partner & search';
  }

  String get _preferredOriginCountryLabel {
    if (_t.isGerman) return 'Bevorzugte Herkunft';
    if (_t.isThai) return 'ประเทศต้นทางที่ต้องการ';
    return 'Preferred origin';
  }

  String get _preferredHairColorLabel {
    if (_t.isGerman) return 'Bevorzugte Haarfarbe';
    if (_t.isThai) return 'สีผมที่ต้องการ';
    return 'Preferred hair color';
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _jobCtrl.dispose();
    _otherJobCtrl.dispose();
    _originCountryCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCodeCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _lineCtrl.dispose();
    _whatsappCtrl.dispose();
    _telegramCtrl.dispose();
    _aboutCtrl.dispose();
    _hobbiesCustomCtrl.dispose();
    _preferredOriginCountryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadProfile(),
      _loadPhotos(),
    ]);
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _supabase
          .from('profiles')
          .select('''
            avatar_url,
            display_name,
            job,
            gender,
            birthdate,
            zodiac_sign,
            languages,
            smoking_status,
            ethnicity,
            origin_country,
            country,
            province,
            postal_code,
            show_postal_code,
            hair_color,
            eye_color,
            height_cm,
            weight_kg,
            body_type,
            job_category,
            other_job,
            line_id,
            whatsapp_number,
            telegram_username,
            about_me,
            bio,
            hobbies,
            desired_partner,
            preferred_age_min,
            preferred_age_max,
            preferred_height_min,
            preferred_height_max,
            preferred_hair_color,
            preferred_origin_country,
            search_radius_km
          ''')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final aboutMe = (row?['about_me'] ?? '').toString().trim();
      final bio = (row?['bio'] ?? '').toString().trim();
      final birthdateRaw = row?['birthdate']?.toString();
      final parsedBirthDate =
          birthdateRaw != null ? DateTime.tryParse(birthdateRaw) : null;

      final loadedLanguages = <String>{};
      final languagesRaw = row?['languages'];
      if (languagesRaw is List) {
        for (final item in languagesRaw) {
          final value = item.toString().trim();
          if (value.isNotEmpty) {
            loadedLanguages.add(value);
          }
        }
      }

      final loadedKnownHobbies = <String>{};
      final loadedCustomHobbies = <String>[];

      final hobbiesRaw = row?['hobbies'];

      if (hobbiesRaw is List) {
        for (final item in hobbiesRaw) {
          final hobby = item.toString().trim();
          if (hobby.isEmpty) continue;

          if (_hobbyOptions.contains(hobby)) {
            loadedKnownHobbies.add(hobby);
          } else {
            loadedCustomHobbies.add(hobby);
          }
        }
      } else {
        final fallback = (hobbiesRaw ?? '').toString().trim();
        if (fallback.isNotEmpty) {
          final parts = fallback
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          for (final hobby in parts) {
            if (_hobbyOptions.contains(hobby)) {
              loadedKnownHobbies.add(hobby);
            } else {
              loadedCustomHobbies.add(hobby);
            }
          }
        }
      }

      final preferredAgeMin =
          (row?['preferred_age_min'] as num?)?.toDouble() ?? 18;
      final preferredAgeMax =
          (row?['preferred_age_max'] as num?)?.toDouble() ?? 60;

      final preferredHeightMin =
          (row?['preferred_height_min'] as num?)?.toDouble() ?? 140;
      final preferredHeightMax =
          (row?['preferred_height_max'] as num?)?.toDouble() ?? 210;

      final searchRadiusKm =
          (row?['search_radius_km'] as num?)?.toDouble() ?? 50;

      setState(() {
        _avatarUrl = row?['avatar_url']?.toString();
        _displayNameCtrl.text = (row?['display_name'] ?? '').toString();
        _jobCtrl.text = (row?['job'] ?? '').toString();
        _otherJobCtrl.text = (row?['other_job'] ?? '').toString();
        _originCountryCtrl.text = (row?['origin_country'] ?? '').toString();
        _provinceCtrl.text = (row?['province'] ?? '').toString();
        _postalCodeCtrl.text = (row?['postal_code'] ?? '').toString();
        _heightCtrl.text = (row?['height_cm'] ?? '').toString();
        _weightCtrl.text = (row?['weight_kg'] ?? '').toString();
        _lineCtrl.text = (row?['line_id'] ?? '').toString();
        _whatsappCtrl.text = (row?['whatsapp_number'] ?? '').toString();
        _telegramCtrl.text = (row?['telegram_username'] ?? '').toString();
        _aboutCtrl.text = aboutMe.isNotEmpty ? aboutMe : bio;
        _hobbiesCustomCtrl.text = loadedCustomHobbies.join(', ');
        _preferredOriginCountryCtrl.text =
            (row?['preferred_origin_country'] ?? '').toString();

        _selectedGender = _safeOption(
          row?['gender']?.toString(),
          _genderOptions,
        );
        _selectedJobCategory = _safeOption(
          row?['job_category']?.toString(),
          _jobOptions,
        );
        _selectedEthnicity = _safeOption(
          row?['ethnicity']?.toString(),
          _ethnicityOptions,
        );
        _selectedCountry = _safeOption(
          row?['country']?.toString(),
          _countryOptions,
        );
        _selectedZodiacSign = _safeOption(
          row?['zodiac_sign']?.toString(),
          _zodiacOptions,
        );
        _selectedSmokingStatus = _safeOption(
          row?['smoking_status']?.toString(),
          _smokingOptions,
        );
        _selectedHairColor = _safeOption(
          row?['hair_color']?.toString(),
          _hairColorOptions,
        );
        _selectedEyeColor = _safeOption(
          row?['eye_color']?.toString(),
          _eyeColorOptions,
        );
        _selectedBodyType = _safeOption(
          row?['body_type']?.toString(),
          _bodyTypeOptions,
        );
        _selectedDesiredPartner = _safeOption(
          row?['desired_partner']?.toString(),
          _desiredPartnerOptions,
        );
        _selectedPreferredHairColor = _safeOption(
          row?['preferred_hair_color']?.toString(),
          _hairColorOptions,
        );

        _birthDate = parsedBirthDate;
        _showPostalCode = row?['show_postal_code'] == true;

        _preferredAgeMin = preferredAgeMin.clamp(18, 99);
        _preferredAgeMax = preferredAgeMax.clamp(_preferredAgeMin, 99);

        _preferredHeightMin = preferredHeightMin.clamp(100, 250);
        _preferredHeightMax =
            preferredHeightMax.clamp(_preferredHeightMin, 250);

        _searchRadiusKm = searchRadiusKm.clamp(1, 500);

        _selectedLanguages
          ..clear()
          ..addAll(
            loadedLanguages.where(
              (language) => _languageOptions.contains(language),
            ),
          );

        _selectedHobbies
          ..clear()
          ..addAll(loadedKnownHobbies);
      });
    } catch (e) {
      _showSnack(_t.profileLoadError(e.toString()));
    }
  }

  Future<void> _loadPhotos() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final photos = await ProfilePhotosService.loadPhotosForUser(user.id);

      if (!mounted) return;

      setState(() {
        _photos = photos;
        _remainingSlots =
            (AccessService.maxUploadPhotosPerProfile - _photos.length)
                .clamp(0, AccessService.maxUploadPhotosPerProfile);
      });
    } catch (e) {
      _showSnack(_t.photosLoadError(e.toString()));
    }
  }

  String? _safeOption(String? value, List<String> options) {
    if (value == null) return null;
    return options.contains(value) ? value : null;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _photoBlockedMessage() {
    if (_t.isGerman) {
      return 'Dieses Bild wurde aus Sicherheitsgründen blockiert. Bitte lade ein anderes Profilbild ohne Nacktheit oder sexuelle Inhalte hoch.';
    }
    if (_t.isThai) {
      return 'รูปภาพนี้ถูกบล็อกเพื่อความปลอดภัย กรุณาอัปโหลดรูปอื่นที่ไม่มีภาพเปลือยหรือเนื้อหาทางเพศ';
    }
    return 'This image was blocked for safety reasons. Please upload another profile photo without nudity or sexual content.';
  }

  String _photoModerationErrorMessage() {
    if (_t.isGerman) {
      return 'Das Bild konnte nicht sicher geprüft werden. Bitte versuche es später erneut oder lade ein anderes Bild hoch.';
    }
    if (_t.isThai) {
      return 'ไม่สามารถตรวจสอบรูปภาพได้อย่างปลอดภัย กรุณาลองใหม่ภายหลังหรืออัปโหลดรูปอื่น';
    }
    return 'The image could not be checked safely. Please try again later or upload another image.';
  }

  Future<bool> _checkPhotoAllowed(Uint8List imageBytes) async {
    try {
      final result = await PhotoModerationService.checkImage(imageBytes);

      if (!result.isAllowed) {
        _showSnack(_photoBlockedMessage());
        return false;
      }

      return true;
    } catch (_) {
      _showSnack(_photoModerationErrorMessage());
      return false;
    }
  }

  Future<Uint8List> _compressImage(Uint8List inputBytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        inputBytes,
        minWidth: 1400,
        minHeight: 1400,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      if (result.isEmpty) return inputBytes;
      return Uint8List.fromList(result);
    } catch (_) {
      return inputBytes;
    }
  }

  Future<void> _pickAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final rawBytes = file.bytes;
    if (rawBytes == null) return;

    setState(() => _isLoading = true);

    try {
      final compressedBytes = await _compressImage(rawBytes);

      final allowed = await _checkPhotoAllowed(compressedBytes);
      if (!allowed) return;

      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${user.id}/avatar/$fileName';

      await _supabase.storage.from(_bucket).uploadBinary(
            path,
            compressedBytes,
          );

      final url = _supabase.storage.from(_bucket).getPublicUrl(path);

      await _supabase.from('profiles').upsert({
        'user_id': user.id,
        'avatar_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (!mounted) return;

      setState(() {
        _avatarUrl = url;
      });

      _showSnack(_t.avatarSaved);
    } catch (e) {
      _showSnack(_t.avatarUploadError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPhoto() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await AccessService.ensureCanUploadOneMore();
    } catch (_) {
      _showSnack(_t.photoLimitReached);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final rawBytes = file.bytes;
    if (rawBytes == null) return;

    setState(() => _isLoading = true);

    try {
      final compressedBytes = await _compressImage(rawBytes);

      final allowed = await _checkPhotoAllowed(compressedBytes);
      if (!allowed) return;

      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${user.id}/gallery/$fileName';

      await _supabase.storage.from(_bucket).uploadBinary(
            path,
            compressedBytes,
          );

      final url = _supabase.storage.from(_bucket).getPublicUrl(path);

      await _supabase.from('profile_photos').insert({
        'user_id': user.id,
        'full_url': url,
        'sort_index': _photos.length,
      });

      await _loadPhotos();
      _showSnack(_t.photoAdded);
    } catch (e) {
      _showSnack(_t.photoUploadError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPhotoPreview(ProfilePhoto photo) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  photo.fullUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 260,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(
                          _t.isGerman
                              ? 'Schließen'
                              : _t.isThai
                                  ? 'ปิด'
                                  : 'Close',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _deletePhoto(photo);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_rounded),
                        label: Text(
                          _t.isGerman
                              ? 'Löschen'
                              : _t.isThai
                                  ? 'ลบ'
                                  : 'Delete',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePhoto(ProfilePhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _t.isGerman
                ? 'Bild löschen?'
                : _t.isThai
                    ? 'ลบรูปภาพ?'
                    : 'Delete photo?',
          ),
          content: Text(
            _t.isGerman
                ? 'Möchtest du dieses Bild wirklich löschen?'
                : _t.isThai
                    ? 'คุณต้องการลบรูปภาพนี้จริงหรือไม่?'
                    : 'Do you really want to delete this photo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _t.isGerman
                    ? 'Löschen'
                    : _t.isThai
                        ? 'ลบ'
                        : 'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('profile_photos').delete().eq('id', photo.id);

      await _loadPhotos();

      _showSnack(
        _t.isGerman
            ? 'Bild wurde gelöscht.'
            : _t.isThai
                ? 'ลบรูปภาพแล้ว'
                : 'Photo deleted.',
      );
    } catch (e) {
      _showSnack(
        _t.isGerman
            ? 'Bild konnte nicht gelöscht werden: $e'
            : _t.isThai
                ? 'ไม่สามารถลบรูปภาพได้: $e'
                : 'Photo could not be deleted: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _birthDate = picked;
    });
  }

  String _formatBirthDate(DateTime? date) {
    if (date == null) return '';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d.$m.$y';
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;

    final hadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);

    if (!hadBirthday) age--;
    return age;
  }

  Future<void> _openLanguageMultiSelect() async {
    final tempSelection = Set<String>.from(_selectedLanguages);
    final t = _t;

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.selectLanguages,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelection.clear();
                              });
                            },
                            child: Text(t.clear),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.multipleChoicePossible,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _languageOptions.map((language) {
                          final selected = tempSelection.contains(language);
                          return CheckboxListTile(
                            value: selected,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(language),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelection.add(language);
                                } else {
                                  tempSelection.remove(language);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(t.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, tempSelection),
                              child: Text(t.apply),
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

    if (result == null || !mounted) return;

    setState(() {
      _selectedLanguages
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _openHobbyMultiSelect() async {
    final tempSelection = Set<String>.from(_selectedHobbies);
    final t = _t;

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.selectHobbies,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelection.clear();
                              });
                            },
                            child: Text(t.clear),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.multipleChoicePossible,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _hobbyOptions.map((hobby) {
                          final selected = tempSelection.contains(hobby);
                          return CheckboxListTile(
                            value: selected,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(hobby),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelection.add(hobby);
                                } else {
                                  tempSelection.remove(hobby);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(t.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, tempSelection),
                              child: Text(t.apply),
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

    if (result == null || !mounted) return;

    setState(() {
      _selectedHobbies
        ..clear()
        ..addAll(result);
    });
  }

  List<String> _buildSavedHobbies() {
    final values = <String>[];

    values.addAll(_selectedHobbies);

    final customRaw = _hobbiesCustomCtrl.text.trim();
    if (customRaw.isNotEmpty) {
      values.addAll(
        customRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final unique = <String>[];
    for (final item in values) {
      if (!unique.contains(item)) {
        unique.add(item);
      }
    }

    return unique;
  }

  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnack(_t.loginRequired);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);

    try {
      final about = _aboutCtrl.text.trim();
      final hobbiesList = _buildSavedHobbies();

      await _supabase.from('profiles').upsert({
        'user_id': user.id,
        'display_name': _displayNameCtrl.text.trim(),
        'job': _jobCtrl.text.trim().isEmpty ? null : _jobCtrl.text.trim(),
        'gender': (_selectedGender == null || _selectedGender!.trim().isEmpty)
            ? null
            : _selectedGender,
        'job_category': _selectedJobCategory,
        'other_job': _otherJobCtrl.text.trim().isEmpty
            ? null
            : _otherJobCtrl.text.trim(),
        'languages': _selectedLanguages.toList(),
        'hobbies': hobbiesList.isEmpty ? null : hobbiesList,
        'ethnicity': _selectedEthnicity,
        'origin_country': _originCountryCtrl.text.trim().isEmpty
            ? null
            : _originCountryCtrl.text.trim(),
        'country': _selectedCountry,
        'province': _provinceCtrl.text.trim().isEmpty
            ? null
            : _provinceCtrl.text.trim(),
        'postal_code': _postalCodeCtrl.text.trim().isEmpty
            ? null
            : _postalCodeCtrl.text.trim(),
        'show_postal_code': _showPostalCode,
        'birthdate': _birthDate?.toIso8601String(),
        'zodiac_sign': _selectedZodiacSign,
        'smoking_status': _selectedSmokingStatus,
        'hair_color': _selectedHairColor,
        'eye_color': _selectedEyeColor,
        'height_cm': _heightCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_heightCtrl.text.trim()),
        'weight_kg': _weightCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_weightCtrl.text.trim()),
        'body_type': _selectedBodyType,
        'desired_partner': _selectedDesiredPartner,
        'preferred_age_min': _preferredAgeMin.round(),
        'preferred_age_max': _preferredAgeMax.round(),
        'preferred_height_min': _preferredHeightMin.round(),
        'preferred_height_max': _preferredHeightMax.round(),
        'preferred_hair_color': _selectedPreferredHairColor,
        'preferred_origin_country':
            _preferredOriginCountryCtrl.text.trim().isEmpty
                ? null
                : _preferredOriginCountryCtrl.text.trim(),
        'search_radius_km': _searchRadiusKm.round(),
        'line_id': _lineCtrl.text.trim().isEmpty ? null : _lineCtrl.text.trim(),
        'whatsapp_number': _whatsappCtrl.text.trim().isEmpty
            ? null
            : _whatsappCtrl.text.trim(),
        'telegram_username': _telegramCtrl.text.trim().isEmpty
            ? null
            : _telegramCtrl.text.trim(),
        'about_me': about.isEmpty ? null : about,
        'bio': about.isEmpty ? null : about,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (!mounted) return;
      _showSnack(_t.profileSaved);
    } catch (e) {
      _showSnack(_t.saveError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Widget _buildAvatar() {
    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _pickAvatar,
        child: CircleAvatar(
          radius: 50,
          backgroundImage:
              _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          child: _avatarUrl == null
              ? const Icon(Icons.camera_alt, size: 40)
              : null,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildStyledChip({
    required String text,
    required VoidCallback onDeleted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 7, bottom: 7),
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            iconSize: 16,
            onPressed: onDeleted,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required IconData icon,
    required String emptyText,
    required List<String> selectedValues,
    required VoidCallback onTap,
    required void Function(String value) onDelete,
  }) {
    final displayText =
        selectedValues.isEmpty ? emptyText : selectedValues.join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayText,
              style: TextStyle(
                color: selectedValues.isEmpty ? Colors.black54 : Colors.black87,
                fontWeight:
                    selectedValues.isEmpty ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
            if (selectedValues.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedValues
                    .map(
                      (value) => _buildStyledChip(
                        text: value,
                        onDeleted: () => onDelete(value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagesDropdown() {
    final selectedSorted = _languageOptions
        .where((language) => _selectedLanguages.contains(language))
        .toList();

    return _buildMultiSelectField(
      label: _t.languages,
      icon: Icons.translate_outlined,
      emptyText: _t.pleaseSelect,
      selectedValues: selectedSorted,
      onTap: _openLanguageMultiSelect,
      onDelete: (language) {
        setState(() {
          _selectedLanguages.remove(language);
        });
      },
    );
  }

  Widget _buildHobbiesDropdown() {
    final selectedSorted =
        _hobbyOptions.where((hobby) => _selectedHobbies.contains(hobby)).toList();

    return _buildMultiSelectField(
      label: _t.hobbies,
      icon: Icons.interests_outlined,
      emptyText: _t.pleaseSelect,
      selectedValues: selectedSorted,
      onTap: _openHobbyMultiSelect,
      onDelete: (hobby) {
        setState(() {
          _selectedHobbies.remove(hobby);
        });
      },
    );
  }

  Widget _buildBirthSection() {
    final t = _t;
    final age = _calculateAge(_birthDate);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: _pickBirthDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _birthDate == null ? t.selectBirthdate : _formatBirthDate(_birthDate),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: t.age,
              border: const OutlineInputBorder(),
            ),
            child: Text(age == null ? '' : age.toString()),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateMessengerInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t.privateMessengerInfo,
              style: TextStyle(
                color: Colors.black.withOpacity(0.68),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeCard({
    required String title,
    required RangeValues values,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<RangeValues> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
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

  Widget _buildSearchRadiusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _searchRadiusLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: _searchRadiusKm,
            min: 1,
            max: 500,
            divisions: 499,
            label: '${_searchRadiusKm.round()} km',
            onChanged: (value) {
              setState(() {
                _searchRadiusKm = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerPreferencesSection() {
    return Column(
      children: [
        _buildDropdownField(
          label: _t.desiredPartner,
          value: _selectedDesiredPartner,
          items: _desiredPartnerOptions,
          icon: Icons.favorite_border_rounded,
          onChanged: (value) {
            setState(() {
              _selectedDesiredPartner = value;
            });
          },
        ),
        const SizedBox(height: 14),
        _buildRangeCard(
          title: _preferredAgeLabel,
          values: RangeValues(_preferredAgeMin, _preferredAgeMax),
          min: 18,
          max: 99,
          divisions: 81,
          onChanged: (values) {
            setState(() {
              _preferredAgeMin = values.start;
              _preferredAgeMax = values.end;
            });
          },
        ),
        const SizedBox(height: 14),
        _buildRangeCard(
          title: _preferredHeightLabel,
          values: RangeValues(_preferredHeightMin, _preferredHeightMax),
          min: 100,
          max: 250,
          divisions: 150,
          onChanged: (values) {
            setState(() {
              _preferredHeightMin = values.start;
              _preferredHeightMax = values.end;
            });
          },
        ),
        const SizedBox(height: 14),
        _buildDropdownField(
          label: _preferredHairColorLabel,
          value: _selectedPreferredHairColor,
          items: _hairColorOptions,
          icon: Icons.brush_outlined,
          onChanged: (value) {
            setState(() {
              _selectedPreferredHairColor = value;
            });
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _preferredOriginCountryCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: _preferredOriginCountryLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.public_outlined),
          ),
        ),
        const SizedBox(height: 14),
        _buildSearchRadiusCard(),
      ],
    );
  }

  Widget _buildProfileForm() {
    final t = _t;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildDropdownField(
            label: t.job,
            value: _selectedJobCategory,
            items: _jobOptions,
            icon: Icons.work_outline,
            onChanged: (value) {
              setState(() {
                _selectedJobCategory = value;
              });
            },
          ),
          const SizedBox(height: 14),
          if (_selectedJobCategory == 'Sonstiges') ...[
            TextFormField(
              controller: _otherJobCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t.otherJob,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _jobCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.jobTitle,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.business_center_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _buildLanguagesDropdown(),
          const SizedBox(height: 14),
          _buildHobbiesDropdown(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _hobbiesCustomCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t.hobbiesFreeText,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit_outlined),
              hintText: t.isGerman
                  ? 'z. B. Tauchen, Streetfood, Camping'
                  : t.isThai
                      ? 'เช่น ดำน้ำ สตรีทฟู้ด แคมป์ปิ้ง'
                      : 'e.g. diving, street food, camping',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.ethnicity,
            value: _selectedEthnicity,
            items: _ethnicityOptions,
            icon: Icons.groups_2_outlined,
            onChanged: (value) {
              setState(() {
                _selectedEthnicity = value;
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _originCountryCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.originCountry,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.country,
            value: _selectedCountry,
            items: _countryOptions,
            icon: Icons.public_outlined,
            onChanged: (value) {
              setState(() {
                _selectedCountry = value;
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _provinceCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.province,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _postalCodeCtrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: t.postalCode,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.showPostalCode),
            subtitle: Text(
              t.isGerman
                  ? 'Wenn nicht aktiviert, wird nur die Provinz öffentlich angezeigt.'
                  : t.isThai
                      ? 'หากไม่เปิดใช้งาน จะแสดงเฉพาะจังหวัดต่อสาธารณะ'
                      : 'If not enabled, only the province will be shown publicly.',
            ),
            value: _showPostalCode,
            onChanged: (value) {
              setState(() {
                _showPostalCode = value ?? false;
              });
            },
          ),
          const SizedBox(height: 14),
          _buildBirthSection(),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.zodiacSign,
            value: _selectedZodiacSign,
            items: _zodiacOptions,
            icon: Icons.auto_awesome_outlined,
            onChanged: (value) {
              setState(() {
                _selectedZodiacSign = value;
              });
            },
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.smokingStatus,
            value: _selectedSmokingStatus,
            items: _smokingOptions,
            icon: Icons.smoking_rooms_outlined,
            onChanged: (value) {
              setState(() {
                _selectedSmokingStatus = value;
              });
            },
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.hairColor,
            value: _selectedHairColor,
            items: _hairColorOptions,
            icon: Icons.brush_outlined,
            onChanged: (value) {
              setState(() {
                _selectedHairColor = value;
              });
            },
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.eyeColor,
            value: _selectedEyeColor,
            items: _eyeColorOptions,
            icon: Icons.visibility_outlined,
            onChanged: (value) {
              setState(() {
                _selectedEyeColor = value;
              });
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${t.height} (cm)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.height_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${t.weight} (kg)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.bodyType,
            value: _selectedBodyType,
            items: _bodyTypeOptions,
            icon: Icons.accessibility_new_outlined,
            onChanged: (value) {
              setState(() {
                _selectedBodyType = value;
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lineCtrl,
            decoration: InputDecoration(
              labelText: t.isGerman
                  ? 'Line ID (privat)'
                  : t.isThai
                      ? 'Line ID (ส่วนตัว)'
                      : 'Line ID (private)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.chat_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _whatsappCtrl,
            decoration: InputDecoration(
              labelText: t.isGerman
                  ? 'WhatsApp (privat)'
                  : t.isThai
                      ? 'WhatsApp (ส่วนตัว)'
                      : 'WhatsApp (private)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telegramCtrl,
            decoration: InputDecoration(
              labelText: t.isGerman
                  ? 'Telegram (privat)'
                  : t.isThai
                      ? 'Telegram (ส่วนตัว)'
                      : 'Telegram (private)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.send_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _buildPrivateMessengerInfo(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _displayNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.displayName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) {
                return t.displayNameRequired;
              }
              if (v.length < 2) {
                return t.displayNameTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildDropdownField(
            label: t.gender,
            value: _selectedGender,
            items: _genderOptions,
            icon: Icons.wc_outlined,
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _aboutCtrl,
            maxLines: 5,
            minLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: t.aboutMe,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _preferredPartnerSectionTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPartnerPreferencesSection(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSavingProfile || _isLoading) ? null : _saveProfile,
              icon: _isSavingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSavingProfile ? t.saving : t.saveProfile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery() {
    final t = _t;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t.photos} (${_photos.length}/${AccessService.maxUploadPhotosPerProfile})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          t.freeSlots(_remainingSlots),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final photo in _photos)
              GestureDetector(
                onTap: _isLoading ? null : () => _openPhotoPreview(photo),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photo.fullUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_remainingSlots > 0)
              GestureDetector(
                onTap: _isLoading ? null : _addPhoto,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Icon(Icons.add_a_photo),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final busy = _isLoading || _isSavingProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.editProfile),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionCard(
                title: t.profilePicture,
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 12),
                    Text(
                      t.profilePictureHint,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: t.yourDetails,
                child: _buildProfileForm(),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: t.yourGallery,
                child: _buildGallery(),
              ),
              const SizedBox(height: 24),
            ],
          ),
          if (busy)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}