class ProfileGeoPoint {
  final double latitude;
  final double longitude;

  const ProfileGeoPoint({
    required this.latitude,
    required this.longitude,
  });
}

class ProfileGeoService {
  const ProfileGeoService._();

  static ProfileGeoPoint? resolve({
    required String? country,
    required String? province,
  }) {
    final cleanCountry = _clean(country);
    final cleanProvince = _clean(province);

    if (cleanCountry.isEmpty && cleanProvince.isEmpty) {
      return null;
    }

    final byProvince = _provinceCoordinates['$cleanCountry|$cleanProvince'];
    if (byProvince != null) {
      return byProvince;
    }

    final byCountry = _countryCoordinates[cleanCountry];
    if (byCountry != null) {
      return byCountry;
    }

    return null;
  }

  static Future<ProfileGeoPoint?> resolveLocation({
    required String? country,
    required String? province,
    String? postalCode,
  }) async {
    return resolve(
      country: country,
      province: province,
    );
  }

  static String _clean(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }

  static const Map<String, ProfileGeoPoint> _countryCoordinates = {
    'thailand': ProfileGeoPoint(latitude: 15.8700, longitude: 100.9925),
    'oesterreich': ProfileGeoPoint(latitude: 47.5162, longitude: 14.5501),
    'deutschland': ProfileGeoPoint(latitude: 51.1657, longitude: 10.4515),
    'schweiz': ProfileGeoPoint(latitude: 46.8182, longitude: 8.2275),
    'frankreich': ProfileGeoPoint(latitude: 46.2276, longitude: 2.2137),
    'italien': ProfileGeoPoint(latitude: 41.8719, longitude: 12.5674),
    'spanien': ProfileGeoPoint(latitude: 40.4637, longitude: -3.7492),
    'portugal': ProfileGeoPoint(latitude: 39.3999, longitude: -8.2245),
    'niederlande': ProfileGeoPoint(latitude: 52.1326, longitude: 5.2913),
    'belgien': ProfileGeoPoint(latitude: 50.5039, longitude: 4.4699),
    'grossbritannien': ProfileGeoPoint(latitude: 55.3781, longitude: -3.4360),
    'usa': ProfileGeoPoint(latitude: 37.0902, longitude: -95.7129),
    'kanada': ProfileGeoPoint(latitude: 56.1304, longitude: -106.3468),
    'australien': ProfileGeoPoint(latitude: -25.2744, longitude: 133.7751),
    'japan': ProfileGeoPoint(latitude: 36.2048, longitude: 138.2529),
    'suedkorea': ProfileGeoPoint(latitude: 35.9078, longitude: 127.7669),
    'china': ProfileGeoPoint(latitude: 35.8617, longitude: 104.1954),
    'singapur': ProfileGeoPoint(latitude: 1.3521, longitude: 103.8198),
    'malaysia': ProfileGeoPoint(latitude: 4.2105, longitude: 101.9758),
    'indonesien': ProfileGeoPoint(latitude: -0.7893, longitude: 113.9213),
    'philippinen': ProfileGeoPoint(latitude: 12.8797, longitude: 121.7740),
    'vietnam': ProfileGeoPoint(latitude: 14.0583, longitude: 108.2772),
    'kambodscha': ProfileGeoPoint(latitude: 12.5657, longitude: 104.9910),
    'laos': ProfileGeoPoint(latitude: 19.8563, longitude: 102.4955),
    'myanmar': ProfileGeoPoint(latitude: 21.9162, longitude: 95.9560),
    'indien': ProfileGeoPoint(latitude: 20.5937, longitude: 78.9629),
  };

  static const Map<String, ProfileGeoPoint> _provinceCoordinates = {
    'thailand|bangkok': ProfileGeoPoint(latitude: 13.7563, longitude: 100.5018),
    'thailand|chiang mai': ProfileGeoPoint(latitude: 18.7883, longitude: 98.9853),
    'thailand|phuket': ProfileGeoPoint(latitude: 7.8804, longitude: 98.3923),
    'thailand|pattaya': ProfileGeoPoint(latitude: 12.9236, longitude: 100.8825),
    'thailand|chonburi': ProfileGeoPoint(latitude: 13.3611, longitude: 100.9847),
    'thailand|nakhon ratchasima': ProfileGeoPoint(latitude: 14.9799, longitude: 102.0977),
    'thailand|khon kaen': ProfileGeoPoint(latitude: 16.4419, longitude: 102.8350),
    'thailand|udon thani': ProfileGeoPoint(latitude: 17.4138, longitude: 102.7872),
    'thailand|chiang rai': ProfileGeoPoint(latitude: 19.9105, longitude: 99.8406),
    'thailand|surat thani': ProfileGeoPoint(latitude: 9.1382, longitude: 99.3215),
    'thailand|krabi': ProfileGeoPoint(latitude: 8.0863, longitude: 98.9063),
    'thailand|hua hin': ProfileGeoPoint(latitude: 12.5684, longitude: 99.9577),
    'thailand|prachuap khiri khan': ProfileGeoPoint(latitude: 11.7938, longitude: 99.7957),

    'oesterreich|wien': ProfileGeoPoint(latitude: 48.2082, longitude: 16.3738),
    'oesterreich|niederoesterreich': ProfileGeoPoint(latitude: 48.1081, longitude: 15.8049),
    'oesterreich|oberoesterreich': ProfileGeoPoint(latitude: 48.0259, longitude: 13.9724),
    'oesterreich|steiermark': ProfileGeoPoint(latitude: 47.3593, longitude: 14.4690),
    'oesterreich|kaernten': ProfileGeoPoint(latitude: 46.7222, longitude: 13.9797),
    'oesterreich|salzburg': ProfileGeoPoint(latitude: 47.8095, longitude: 13.0550),
    'oesterreich|tirol': ProfileGeoPoint(latitude: 47.2537, longitude: 11.6015),
    'oesterreich|vorarlberg': ProfileGeoPoint(latitude: 47.2497, longitude: 9.9797),
    'oesterreich|burgenland': ProfileGeoPoint(latitude: 47.1537, longitude: 16.2689),

    'deutschland|berlin': ProfileGeoPoint(latitude: 52.5200, longitude: 13.4050),
    'deutschland|muenchen': ProfileGeoPoint(latitude: 48.1351, longitude: 11.5820),
    'deutschland|hamburg': ProfileGeoPoint(latitude: 53.5511, longitude: 9.9937),
    'deutschland|koeln': ProfileGeoPoint(latitude: 50.9375, longitude: 6.9603),
    'deutschland|frankfurt': ProfileGeoPoint(latitude: 50.1109, longitude: 8.6821),
    'deutschland|stuttgart': ProfileGeoPoint(latitude: 48.7758, longitude: 9.1829),
    'deutschland|duesseldorf': ProfileGeoPoint(latitude: 51.2277, longitude: 6.7735),

    'schweiz|zuerich': ProfileGeoPoint(latitude: 47.3769, longitude: 8.5417),
    'schweiz|bern': ProfileGeoPoint(latitude: 46.9480, longitude: 7.4474),
    'schweiz|basel': ProfileGeoPoint(latitude: 47.5596, longitude: 7.5886),
    'schweiz|genf': ProfileGeoPoint(latitude: 46.2044, longitude: 6.1432),
  };
}