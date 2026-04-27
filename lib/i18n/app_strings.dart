import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;

  AppStrings(this.locale);

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('th'),
  ];

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String get languageCode => locale.languageCode;

  bool get isGerman => languageCode == 'de';
  bool get isThai => languageCode == 'th';
  bool get isEnglish => languageCode == 'en';

  String _t({
    required String en,
    required String de,
    required String th,
  }) {
    switch (languageCode) {
      case 'de':
        return de;
      case 'th':
        return th;
      default:
        return en;
    }
  }

  String get appName => _t(
        en: 'Meet Thai',
        de: 'Meet Thai',
        th: 'มีตไทย',
      );

  String get home => _t(
        en: 'Home',
        de: 'Home',
        th: 'หน้าหลัก',
      );

  String get search => _t(
        en: 'Search',
        de: 'Suche',
        th: 'ค้นหา',
      );

  String get matches => _t(
        en: 'Matches',
        de: 'Matches',
        th: 'แมตช์',
      );

  String get likes => _t(
        en: 'Likes',
        de: 'Likes',
        th: 'ไลก์',
      );

  String get chats => _t(
        en: 'Chats',
        de: 'Chats',
        th: 'แชต',
      );

  String get profile => _t(
        en: 'Profile',
        de: 'Profil',
        th: 'โปรไฟล์',
      );

  String get editProfile => _t(
        en: 'Edit profile',
        de: 'Profil bearbeiten',
        th: 'แก้ไขโปรไฟล์',
      );

  String get saveProfile => _t(
        en: 'Save profile',
        de: 'Profil speichern',
        th: 'บันทึกโปรไฟล์',
      );

  String get saving => _t(
        en: 'Saving...',
        de: 'Speichert...',
        th: 'กำลังบันทึก...',
      );

  String get displayName => _t(
        en: 'Display name',
        de: 'Anzeigename',
        th: 'ชื่อที่แสดง',
      );

  String get gender => _t(
        en: 'Gender',
        de: 'Geschlecht',
        th: 'เพศ',
      );

  String get job => _t(
        en: 'Job',
        de: 'Job',
        th: 'อาชีพ',
      );

  String get jobTitle => _t(
        en: 'Job title',
        de: 'Berufsbezeichnung',
        th: 'ตำแหน่งงาน',
      );

  String get languages => _t(
        en: 'Languages',
        de: 'Sprachen',
        th: 'ภาษา',
      );

  String get hobbies => _t(
        en: 'Hobbies',
        de: 'Hobbies',
        th: 'งานอดิเรก',
      );

  String get hobbiesFreeText => _t(
        en: 'Additional hobbies (free text)',
        de: 'Weitere Hobbies (Freitext)',
        th: 'งานอดิเรกเพิ่มเติม (ข้อความอิสระ)',
      );

  String get desiredPartner => _t(
        en: 'Desired partner',
        de: 'Gewünschter Partner',
        th: 'คู่ที่ต้องการ',
      );

  String get aboutMe => _t(
        en: 'About me',
        de: 'Über mich',
        th: 'เกี่ยวกับฉัน',
      );

  String get originCountry => _t(
        en: 'Country of origin',
        de: 'Herkunftsland',
        th: 'ประเทศต้นทาง',
      );

  String get country => _t(
        en: 'Country',
        de: 'Land',
        th: 'ประเทศ',
      );

  String get province => _t(
        en: 'Province / State',
        de: 'Provinz / Bundesland',
        th: 'จังหวัด / รัฐ',
      );

  String get postalCode => _t(
        en: 'Postal code',
        de: 'Postleitzahl',
        th: 'รหัสไปรษณีย์',
      );

  String get showPostalCode => _t(
        en: 'Show postal code in profile',
        de: 'Postleitzahl im Profil anzeigen',
        th: 'แสดงรหัสไปรษณีย์ในโปรไฟล์',
      );

  String get birthdate => _t(
        en: 'Birthdate',
        de: 'Geburtsdatum',
        th: 'วันเกิด',
      );

  String get age => _t(
        en: 'Age',
        de: 'Alter',
        th: 'อายุ',
      );

  String get zodiacSign => _t(
        en: 'Zodiac sign',
        de: 'Sternzeichen',
        th: 'ราศี',
      );

  String get smokingStatus => _t(
        en: 'Smoking status',
        de: 'Raucherstatus',
        th: 'สถานะการสูบบุหรี่',
      );

  String get hairColor => _t(
        en: 'Hair color',
        de: 'Haarfarbe',
        th: 'สีผม',
      );

  String get eyeColor => _t(
        en: 'Eye color',
        de: 'Augenfarbe',
        th: 'สีตา',
      );

  String get height => _t(
        en: 'Height',
        de: 'Größe',
        th: 'ส่วนสูง',
      );

  String get weight => _t(
        en: 'Weight',
        de: 'Gewicht',
        th: 'น้ำหนัก',
      );

  String get bodyType => _t(
        en: 'Body type',
        de: 'Figur',
        th: 'รูปร่าง',
      );

  String get logout => _t(
        en: 'Logout',
        de: 'Logout',
        th: 'ออกจากระบบ',
      );

  String get refresh => _t(
        en: 'Refresh',
        de: 'Aktualisieren',
        th: 'รีเฟรช',
      );

  String get blockedUsers => _t(
        en: 'Blocked users',
        de: 'Blockierte Nutzer',
        th: 'ผู้ใช้ที่ถูกบล็อก',
      );

  String get discoverProfiles => _t(
        en: 'Discover profiles',
        de: 'Profile entdecken',
        th: 'ค้นหาโปรไฟล์',
      );

  String get noProfilesFound => _t(
        en: 'No profiles found.',
        de: 'Keine Profile gefunden.',
        th: 'ไม่พบโปรไฟล์',
      );

  String get like => _t(
        en: 'Like',
        de: 'Like',
        th: 'ไลก์',
      );

  String get superLike => _t(
        en: 'Super Like',
        de: 'Super Like',
        th: 'ซูเปอร์ไลก์',
      );

  String get nope => _t(
        en: 'Nope',
        de: 'Nope',
        th: 'ไม่ใช่',
      );

  String get chatOpen => _t(
        en: 'Open chat',
        de: 'Chat öffnen',
        th: 'เปิดแชต',
      );

  String get continueSwiping => _t(
        en: 'Continue swiping',
        de: 'Weiter swipen',
        th: 'ปัดต่อ',
      );

  String itsAMatch(String name) => _t(
        en: 'You and $name liked each other.',
        de: 'Du und $name habt euch geliked.',
        th: 'คุณและ $name กดไลก์กันแล้ว',
      );

  String get profileSaved => _t(
        en: 'Profile saved',
        de: 'Profil gespeichert',
        th: 'บันทึกโปรไฟล์แล้ว',
      );

  String get selectLanguages => _t(
        en: 'Select languages',
        de: 'Sprachen auswählen',
        th: 'เลือกภาษา',
      );

  String get selectHobbies => _t(
        en: 'Select hobbies',
        de: 'Hobbies auswählen',
        th: 'เลือกงานอดิเรก',
      );

  String get multipleChoicePossible => _t(
        en: 'Multiple selection possible',
        de: 'Mehrfachauswahl möglich',
        th: 'สามารถเลือกได้หลายรายการ',
      );

  String get clear => _t(
        en: 'Clear',
        de: 'Leeren',
        th: 'ล้าง',
      );

  String get cancel => _t(
        en: 'Cancel',
        de: 'Abbrechen',
        th: 'ยกเลิก',
      );

  String get apply => _t(
        en: 'Apply',
        de: 'Übernehmen',
        th: 'ยืนยัน',
      );

  String get pleaseSelect => _t(
        en: 'Please select',
        de: 'Bitte auswählen',
        th: 'กรุณาเลือก',
      );

  String get loginRequired => _t(
        en: 'Please log in.',
        de: 'Bitte logge dich ein.',
        th: 'กรุณาเข้าสู่ระบบ',
      );

  String get toLogin => _t(
        en: 'To login',
        de: 'Zum Login',
        th: 'ไปเข้าสู่ระบบ',
      );

  String get login => _t(
        en: 'Login',
        de: 'Einloggen',
        th: 'เข้าสู่ระบบ',
      );

  String get register => _t(
        en: 'Register',
        de: 'Registrieren',
        th: 'สมัครสมาชิก',
      );

  String get loginSubtitle => _t(
        en: 'Log in to continue.',
        de: 'Melde dich an, um weiterzumachen.',
        th: 'เข้าสู่ระบบเพื่อดำเนินการต่อ',
      );

  String get registerSubtitle => _t(
        en: 'Create an account to get started.',
        de: 'Erstelle ein Konto, um loszulegen.',
        th: 'สร้างบัญชีเพื่อเริ่มต้น',
      );

  String get email => _t(
        en: 'Email',
        de: 'E-Mail',
        th: 'อีเมล',
      );

  String get password => _t(
        en: 'Password',
        de: 'Passwort',
        th: 'รหัสผ่าน',
      );

  String get enterEmail => _t(
        en: 'Please enter your email',
        de: 'Bitte E-Mail eingeben',
        th: 'กรุณากรอกอีเมล',
      );

  String get invalidEmail => _t(
        en: 'Please enter a valid email',
        de: 'Bitte gültige E-Mail eingeben',
        th: 'กรุณากรอกอีเมลที่ถูกต้อง',
      );

  String get enterPassword => _t(
        en: 'Please enter your password',
        de: 'Bitte Passwort eingeben',
        th: 'กรุณากรอกรหัสผ่าน',
      );

  String get passwordTooShort => _t(
        en: 'Minimum 6 characters',
        de: 'Mind. 6 Zeichen',
        th: 'อย่างน้อย 6 ตัวอักษร',
      );

  String get noAccount => _t(
        en: 'No account yet? Register',
        de: 'Noch kein Konto? Registrieren',
        th: 'ยังไม่มีบัญชี? สมัครสมาชิก',
      );

  String get haveAccount => _t(
        en: 'Already have an account? Login',
        de: 'Schon ein Konto? Einloggen',
        th: 'มีบัญชีแล้ว? เข้าสู่ระบบ',
      );

  String get loginScreenActive => _t(
        en: 'Login screen active',
        de: 'Login Screen aktiv',
        th: 'หน้าจอเข้าสู่ระบบพร้อมใช้งาน',
      );

  String get errorLoginNoUser => _t(
        en: 'Login failed (no user).',
        de: 'Login fehlgeschlagen (kein User).',
        th: 'เข้าสู่ระบบไม่สำเร็จ (ไม่พบผู้ใช้)',
      );

  String get emailNotConfirmed => _t(
        en: 'Email not confirmed yet.\nPlease confirm the link in your inbox.',
        de:
            'E-Mail ist noch nicht bestätigt.\nBitte bestätige den Link in deinem Postfach.',
        th: 'อีเมลยังไม่ได้รับการยืนยัน\nกรุณายืนยันลิงก์ในกล่องจดหมายของคุณ',
      );

  String get authError => _t(
        en: 'Auth error',
        de: 'Auth Fehler',
        th: 'ข้อผิดพลาดการยืนยันตัวตน',
      );

  String get error => _t(
        en: 'Error',
        de: 'Fehler',
        th: 'ข้อผิดพลาด',
      );

  String get language => _t(
        en: 'Language',
        de: 'Sprache',
        th: 'ภาษา',
      );

  String get systemLanguage => _t(
        en: 'System language',
        de: 'Systemsprache',
        th: 'ภาษาของระบบ',
      );

  String get germanLanguage => _t(
        en: 'German',
        de: 'Deutsch',
        th: 'เยอรมัน',
      );

  String get englishLanguage => _t(
        en: 'English',
        de: 'English',
        th: 'อังกฤษ',
      );

  String get thaiLanguage => _t(
        en: 'Thai',
        de: 'Thai',
        th: 'ไทย',
      );

  String get more => _t(
        en: 'More',
        de: 'Mehr',
        th: 'เพิ่มเติม',
      );

  String get reloadStatus => _t(
        en: 'Reload status',
        de: 'Status neu laden',
        th: 'รีโหลดสถานะ',
      );

  String get viewProfile => _t(
        en: 'View profile',
        de: 'Profil ansehen',
        th: 'ดูโปรไฟล์',
      );

  String get unblock => _t(
        en: 'Unblock',
        de: 'Entblocken',
        th: 'เลิกบล็อก',
      );

  String get block => _t(
        en: 'Block',
        de: 'Blockieren',
        th: 'บล็อก',
      );

  String get report => _t(
        en: 'Report',
        de: 'Melden',
        th: 'รายงาน',
      );

  String get visible => _t(
        en: 'Visible',
        de: 'Sichtbar',
        th: 'มองเห็นได้',
      );

  String get reload => _t(
        en: 'Reload',
        de: 'Neu laden',
        th: 'โหลดใหม่',
      );

  String get unlockNow => _t(
        en: 'Unlock now',
        de: 'Jetzt freischalten',
        th: 'ปลดล็อกตอนนี้',
      );

  String get activePlan => _t(
        en: 'Active plan',
        de: 'Aktiver Plan',
        th: 'แผนที่ใช้งานอยู่',
      );

  String get noPackagesAvailable => _t(
        en: 'No packages currently available.',
        de: 'Aktuell keine Pakete verfügbar.',
        th: 'ขณะนี้ยังไม่มีแพ็กเกจ',
      );

  String profileLoadError(String error) => _t(
        en: 'Profile could not be loaded: $error',
        de: 'Profil konnte nicht geladen werden: $error',
        th: 'ไม่สามารถโหลดโปรไฟล์ได้: $error',
      );

  String photosLoadError(String error) => _t(
        en: 'Error loading photos: $error',
        de: 'Fehler beim Laden der Fotos: $error',
        th: 'เกิดข้อผิดพลาดในการโหลดรูป: $error',
      );

  String get avatarSaved => _t(
        en: 'Profile photo saved',
        de: 'Profilfoto gespeichert',
        th: 'บันทึกรูปโปรไฟล์แล้ว',
      );

  String avatarUploadError(String error) => _t(
        en: 'Error uploading avatar: $error',
        de: 'Fehler beim Avatar Upload: $error',
        th: 'เกิดข้อผิดพลาดในการอัปโหลดรูปโปรไฟล์: $error',
      );

  String get photoLimitReached => _t(
        en: 'You already uploaded 30 photos.',
        de: 'Du hast bereits 30 Fotos hochgeladen.',
        th: 'คุณอัปโหลดรูปครบ 30 รูปแล้ว',
      );

  String get photoAdded => _t(
        en: 'Photo added',
        de: 'Foto hinzugefügt',
        th: 'เพิ่มรูปแล้ว',
      );

  String photoUploadError(String error) => _t(
        en: 'Error uploading photo: $error',
        de: 'Fehler beim Foto Upload: $error',
        th: 'เกิดข้อผิดพลาดในการอัปโหลดรูป: $error',
      );

  String saveError(String error) => _t(
        en: 'Error saving: $error',
        de: 'Fehler beim Speichern: $error',
        th: 'เกิดข้อผิดพลาดในการบันทึก: $error',
      );

  String get selectBirthdate => _t(
        en: 'Select birthdate',
        de: 'Geburtsdatum wählen',
        th: 'เลือกวันเกิด',
      );

  String get privateMessengerInfo => _t(
        en: 'Line, WhatsApp and Telegram are private fields and are not shown publicly in your profile to other users.',
        de: 'Line, WhatsApp und Telegram sind private Felder und werden nicht öffentlich im Profil für andere Nutzer angezeigt.',
        th: 'Line, WhatsApp และ Telegram เป็นข้อมูลส่วนตัวและจะไม่แสดงสาธารณะในโปรไฟล์ให้ผู้ใช้อื่นเห็น',
      );

  String get otherJob => _t(
        en: 'Other job',
        de: 'Sonstiger Job',
        th: 'อาชีพอื่น',
      );

  String get ethnicity => _t(
        en: 'Ethnicity',
        de: 'Herkunft',
        th: 'เชื้อชาติ',
      );

  String get displayNameRequired => _t(
        en: 'Please enter display name',
        de: 'Bitte Anzeigename eingeben',
        th: 'กรุณากรอกชื่อที่แสดง',
      );

  String get displayNameTooShort => _t(
        en: 'At least 2 characters',
        de: 'Mindestens 2 Zeichen',
        th: 'อย่างน้อย 2 ตัวอักษร',
      );

  String get photos => _t(
        en: 'Photos',
        de: 'Fotos',
        th: 'รูปภาพ',
      );

  String freeSlots(int count) => _t(
        en: 'Free slots: $count',
        de: 'Freie Slots: $count',
        th: 'ช่องว่างที่เหลือ: $count',
      );

  String get profilePicture => _t(
        en: 'Profile picture',
        de: 'Profilbild',
        th: 'รูปโปรไฟล์',
      );

  String get profilePictureHint => _t(
        en: 'Tap your profile picture to change it.',
        de: 'Tippe auf dein Profilbild, um es zu ändern.',
        th: 'แตะรูปโปรไฟล์เพื่อเปลี่ยน',
      );

  String get yourDetails => _t(
        en: 'Your details',
        de: 'Deine Angaben',
        th: 'ข้อมูลของคุณ',
      );

  String get yourGallery => _t(
        en: 'Your gallery',
        de: 'Deine Galerie',
        th: 'แกลเลอรีของคุณ',
      );
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'de', 'th'].contains(locale.languageCode);
  }

  @override
  Future<AppStrings> load(Locale locale) async {
    return AppStrings(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) {
    return false;
  }
}