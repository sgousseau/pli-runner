import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pli_runner/core/models/pli.dart';
import 'package:pli_runner/features/plis/data/pli_repository.dart';
import 'package:pli_runner/features/plis/domain/geocoding_service.dart';
import 'package:pli_runner/features/plis/domain/geofencing_service.dart';
import 'package:pli_runner/features/plis/domain/ocr_service.dart';
import 'package:pli_runner/features/settings/data/settings_repository.dart';
import 'package:pli_runner/features/telegram/data/telegram_service.dart';
import 'package:uuid/uuid.dart';

// --- Services ---

final telegramServiceProvider = Provider<TelegramService>((ref) => TelegramService());
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());
final geocodingServiceProvider = Provider<GeocodingService>((ref) => GeocodingService());
final pliRepositoryProvider = Provider<PliRepository>((ref) => PliRepository());
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

// --- Plis State ---

final plisProvider = StateNotifierProvider<PlisNotifier, List<Pli>>((ref) {
  return PlisNotifier(ref);
});

class PlisNotifier extends StateNotifier<List<Pli>> {
  final Ref _ref;

  PlisNotifier(this._ref) : super([]) {
    _loadPlis();
  }

  Future<void> _loadPlis() async {
    state = await _ref.read(pliRepositoryProvider).getAll();
  }

  Future<void> addPli(Pli pli) async {
    await _ref.read(pliRepositoryProvider).save(pli);
    state = [pli, ...state];
  }

  Future<void> updatePliStatus(String id, PliStatus status) async {
    final index = state.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final updated = state[index].copyWith(status: status);
    await _ref.read(pliRepositoryProvider).save(updated);
    state = [...state]..[index] = updated;
  }

  Future<void> updatePliCoordinates(String id, double lat, double lng) async {
    final index = state.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final updated = state[index].copyWith(latitude: lat, longitude: lng);
    await _ref.read(pliRepositoryProvider).save(updated);
    state = [...state]..[index] = updated;
  }

  Future<void> refresh() => _loadPlis();
}

// --- Telegram Polling ---

final telegramPollingProvider = Provider<TelegramPollingController>((ref) {
  return TelegramPollingController(ref);
});

class TelegramPollingController {
  final Ref _ref;
  Timer? _timer;
  final _notifiedPliIds = <String>{};

  TelegramPollingController(this._ref);

  Future<void> start() async {
    final settings = _ref.read(settingsRepositoryProvider);
    final token = await settings.getBotToken();
    if (token == null || token.isEmpty) return;

    final telegram = _ref.read(telegramServiceProvider);
    telegram.configure(token);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
    _poll(); // Poll immediately
  }

  Future<void> _poll() async {
    final telegram = _ref.read(telegramServiceProvider);
    final photos = await telegram.pollForPhotos();

    for (final photo in photos) {
      // Save dispatch chat ID
      final settings = _ref.read(settingsRepositoryProvider);
      await settings.setDispatchChatId(photo.chatId);

      // Download photo
      final photoPath = await telegram.downloadPhoto(photo.fileId);
      if (photoPath == null) continue;

      // OCR
      final ocr = _ref.read(ocrServiceProvider);
      final result = await ocr.extractFromImage(photoPath);

      final clientNumber = result.clientNumber ?? 'Inconnu';
      final address = result.address ?? result.rawText;
      if (address.isEmpty) continue;

      // Create pli
      final pli = Pli(
        id: const Uuid().v4(),
        clientNumber: clientNumber,
        address: address,
        createdAt: DateTime.now(),
        telegramMessageId: photo.messageId,
        photoPath: photoPath,
      );

      await _ref.read(plisProvider.notifier).addPli(pli);

      // Geocode in background
      _geocodePli(pli);
    }
  }

  Future<void> _geocodePli(Pli pli) async {
    final geocoding = _ref.read(geocodingServiceProvider);
    final result = await geocoding.geocodeAddress(pli.address);
    if (result != null) {
      await _ref.read(plisProvider.notifier).updatePliCoordinates(
            pli.id,
            result.latitude,
            result.longitude,
          );
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // --- Geofencing integration ---

  GeofencingService? _geofencing;

  Future<void> startGeofencing() async {
    final settings = _ref.read(settingsRepositoryProvider);
    final radius = await settings.getGeofenceRadius();
    final messageTemplate = await settings.getApproachMessage();

    _geofencing = GeofencingService(
      radiusMeters: radius,
      onApproaching: (pli, distance) => _onApproaching(pli, distance, messageTemplate),
    );

    final hasPermission = await _geofencing!.requestPermissions();
    if (!hasPermission) return;

    // Watch current pending plis
    _geofencing!.updateWatchedPlis(_ref.read(plisProvider));
    await _geofencing!.startTracking();

    // Update watched plis when state changes
    _ref.listen(plisProvider, (_, plis) {
      _geofencing?.updateWatchedPlis(plis);
    });
  }

  Future<void> _onApproaching(Pli pli, double distance, String messageTemplate) async {
    if (_notifiedPliIds.contains(pli.id)) return;
    _notifiedPliIds.add(pli.id);

    final message = messageTemplate.replaceAll('{clientNumber}', pli.clientNumber);

    // Send Telegram message to dispatch
    final settings = _ref.read(settingsRepositoryProvider);
    final chatId = await settings.getDispatchChatId();
    if (chatId != null) {
      final telegram = _ref.read(telegramServiceProvider);
      await telegram.sendMessage(chatId, message);
    }

    // Local notification
    await _showLocalNotification(pli, distance);
  }

  Future<void> _showLocalNotification(Pli pli, double distance) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      pli.hashCode,
      'Approche pli ${pli.clientNumber}',
      '${distance.round()}m - ${pli.address}',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails('geofence', 'Géofencing', importance: Importance.high),
      ),
    );
  }

  void stopGeofencing() {
    _geofencing?.stop();
  }
}
