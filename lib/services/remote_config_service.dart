import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../config.dart';

class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  late final FirebaseRemoteConfig _remoteConfig;

  int dailyLikeLimit = Config.defaultDailyLikeLimit;
  bool maintenanceMode = Config.defaultMaintenanceMode;
  bool premiumEnabled = Config.defaultPremiumEnabled;
  String minimumSupportedVersion = Config.defaultMinimumSupportedVersion;

  Future<void> init() async {
    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setDefaults({
      'daily_like_limit': Config.defaultDailyLikeLimit,
      'maintenance_mode': Config.defaultMaintenanceMode,
      'premium_enabled': Config.defaultPremiumEnabled,
      'minimum_supported_version': Config.defaultMinimumSupportedVersion,
    });

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );

    await _remoteConfig.fetchAndActivate();

    dailyLikeLimit = _remoteConfig.getInt('daily_like_limit');
    maintenanceMode = _remoteConfig.getBool('maintenance_mode');
    premiumEnabled = _remoteConfig.getBool('premium_enabled');
    minimumSupportedVersion =
        _remoteConfig.getString('minimum_supported_version');

    debugPrint(
      'RemoteConfig daily_like_limit=$dailyLikeLimit, '
      'maintenance_mode=$maintenanceMode, '
      'premium_enabled=$premiumEnabled, '
      'minimum_supported_version=$minimumSupportedVersion',
    );
  }
}
