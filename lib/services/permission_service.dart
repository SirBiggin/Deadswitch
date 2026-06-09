import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Returns true only when every required permission is granted.
  static Future<bool> get allGranted async {
    final results = await Future.wait([
      Permission.notification.status,
      Permission.contacts.status,
      Permission.ignoreBatteryOptimizations.status,
      Permission.sms.status,
    ]);
    return results.every((s) => s.isGranted);
  }

  static Future<PermissionStatus> get notificationStatus =>
      Permission.notification.status;
  static Future<PermissionStatus> get contactsStatus =>
      Permission.contacts.status;
  static Future<PermissionStatus> get batteryStatus =>
      Permission.ignoreBatteryOptimizations.status;
  static Future<PermissionStatus> get smsStatus =>
      Permission.sms.status;

  static Future<PermissionStatus> requestNotification() =>
      Permission.notification.request();
  static Future<PermissionStatus> requestContacts() =>
      Permission.contacts.request();
  static Future<PermissionStatus> requestBattery() =>
      Permission.ignoreBatteryOptimizations.request();
  static Future<PermissionStatus> requestSms() =>
      Permission.sms.request();
}
