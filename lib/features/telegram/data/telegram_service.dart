import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class TelegramService {
  final Dio _dio;
  String? _botToken;
  int _lastUpdateId = 0;

  TelegramService({Dio? dio}) : _dio = dio ?? Dio();

  String get _baseUrl => 'https://api.telegram.org/bot$_botToken';

  void configure(String botToken) {
    _botToken = botToken;
  }

  bool get isConfigured => _botToken != null && _botToken!.isNotEmpty;

  /// Poll for new messages containing photos
  Future<List<TelegramPhoto>> pollForPhotos() async {
    if (!isConfigured) return [];

    try {
      final response = await _dio.get(
        '$_baseUrl/getUpdates',
        queryParameters: {
          'offset': _lastUpdateId + 1,
          'timeout': 5,
          'allowed_updates': ['message'],
        },
      );

      final results = <TelegramPhoto>[];
      final updates = response.data['result'] as List? ?? [];

      for (final update in updates) {
        final updateId = update['update_id'] as int;
        if (updateId > _lastUpdateId) _lastUpdateId = updateId;

        final message = update['message'] as Map<String, dynamic>?;
        if (message == null) continue;

        final photos = message['photo'] as List?;
        if (photos == null || photos.isEmpty) continue;

        // Get the largest photo
        final largestPhoto = photos.last as Map<String, dynamic>;
        final fileId = largestPhoto['file_id'] as String;
        final chatId = message['chat']['id'] as int;
        final messageId = message['message_id'] as int;
        final caption = message['caption'] as String?;

        results.add(TelegramPhoto(
          fileId: fileId,
          chatId: chatId,
          messageId: messageId,
          caption: caption,
        ));
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Download a photo to local storage
  Future<String?> downloadPhoto(String fileId) async {
    if (!isConfigured) return null;

    try {
      // Get file path from Telegram
      final fileResponse = await _dio.get('$_baseUrl/getFile', queryParameters: {'file_id': fileId});
      final filePath = fileResponse.data['result']['file_path'] as String;

      // Download the file
      final downloadUrl = 'https://api.telegram.org/file/bot$_botToken/$filePath';
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/pli_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Directory('${dir.path}/pli_photos').create(recursive: true);
      await _dio.download(downloadUrl, localPath);

      return localPath;
    } catch (e) {
      return null;
    }
  }

  /// Send a message to the dispatch chat
  Future<bool> sendMessage(int chatId, String text) async {
    if (!isConfigured) return false;

    try {
      await _dio.post('$_baseUrl/sendMessage', data: {
        'chat_id': chatId,
        'text': text,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}

class TelegramPhoto {
  final String fileId;
  final int chatId;
  final int messageId;
  final String? caption;

  const TelegramPhoto({
    required this.fileId,
    required this.chatId,
    required this.messageId,
    this.caption,
  });
}
