import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<String> get httpsmsKey async => (await _p).getString('httpsms_key') ?? '';
  static Future<String> get httpsmsFrom async => (await _p).getString('httpsms_from') ?? '';
  static Future<String> get pin async => (await _p).getString('pin') ?? '';
  static Future<bool>   get webPortalEnabled async => (await _p).getBool('web_portal') ?? false;

  static Future<void> setHttpsmsKey(String v) async => (await _p).setString('httpsms_key', v);
  static Future<void> setHttpsmsFrom(String v) async => (await _p).setString('httpsms_from', v);
  static Future<void> setPin(String v) async => (await _p).setString('pin', v);
  static Future<void> setWebPortalEnabled(bool v) async => (await _p).setBool('web_portal', v);
  static Future<bool>  get hasPin async => (await pin).isNotEmpty;
}
