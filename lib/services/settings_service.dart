import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<String> get pin async => (await _p).getString('pin') ?? '';
  static Future<bool>   get webPortalEnabled async => (await _p).getBool('web_portal') ?? false;
  static Future<String> get countryCode async => (await _p).getString('country_code') ?? '1';
  static Future<int>    get delayMinutes async => (await _p).getInt('delay_minutes') ?? 15;
  static Future<bool>   get hasPin async => (await pin).isNotEmpty;

  static Future<void> setPin(String v) async => (await _p).setString('pin', v);
  static Future<void> setWebPortalEnabled(bool v) async => (await _p).setBool('web_portal', v);
  static Future<void> setCountryCode(String v) async => (await _p).setString('country_code', v);
  static Future<void> setDelayMinutes(int v) async => (await _p).setInt('delay_minutes', v);

  // Shared E.164 normalization — used by sms_service, settings_screen, messages_screen
  static String normalizePhone(String phone, String countryCode) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return trimmed;
    if (trimmed.startsWith('00')) return '+${trimmed.substring(2)}';
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return trimmed;
    if (digits.startsWith(countryCode) && digits.length > countryCode.length) return '+$digits';
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '+$countryCode$local';
  }
}
