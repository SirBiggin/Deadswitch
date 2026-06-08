import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<String> get pin              async => (await _p).getString('pin') ?? '';
  static Future<bool>   get webPortalEnabled async => (await _p).getBool('web_portal') ?? false;
  static Future<bool>   get hasPin           async => (await pin).isNotEmpty;

  static Future<void> setPin(String v)              async => (await _p).setString('pin', v);
  static Future<void> setWebPortalEnabled(bool v)   async => (await _p).setBool('web_portal', v);
}
