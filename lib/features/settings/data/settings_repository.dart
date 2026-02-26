import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  Future<String?> getBotToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('botToken');
  }

  Future<void> setBotToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('botToken', token);
  }

  Future<int?> getDispatchChatId() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt('dispatchChatId');
    return val;
  }

  Future<void> setDispatchChatId(int chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dispatchChatId', chatId);
  }

  Future<double> getGeofenceRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('geofenceRadius') ?? 500.0;
  }

  Future<void> setGeofenceRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('geofenceRadius', radius);
  }

  Future<String> getApproachMessage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('approachMessage') ??
        "J'arrive dans ~3 minutes pour le pli {clientNumber}";
  }

  Future<void> setApproachMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('approachMessage', message);
  }
}
