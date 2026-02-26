import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? clientNumber;
  final String? address;
  final String rawText;

  const OcrResult({this.clientNumber, this.address, required this.rawText});
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  Future<OcrResult> extractFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);

    final rawText = recognized.text;
    final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.isEmpty) {
      return OcrResult(rawText: rawText);
    }

    // Client number is at the top of the image
    final clientNumber = _extractClientNumber(lines);

    // Address is typically the remaining meaningful text
    final address = _extractAddress(lines, clientNumber);

    return OcrResult(
      clientNumber: clientNumber,
      address: address,
      rawText: rawText,
    );
  }

  /// Extract client/reference number from the first lines
  String? _extractClientNumber(List<String> lines) {
    // Look for patterns like: #123, N°123, Ref: 123, Client: 123, or just a number at the top
    for (final line in lines.take(3)) {
      final cleaned = line.trim();

      // Match common patterns: #XXX, N°XXX, Ref XXX, Client XXX
      final patterns = [
        RegExp(r'#\s*(\w+[-/]?\w*)'),
        RegExp(r'[Nn]°?\s*(\w+[-/]?\w*)'),
        RegExp(r'[Rr][ée]f\.?\s*:?\s*(\w+[-/]?\w*)'),
        RegExp(r'[Cc]lient\s*:?\s*(\w+[-/]?\w*)'),
        RegExp(r'[Cc]ommande\s*:?\s*(\w+[-/]?\w*)'),
        RegExp(r'[Pp]li\s*:?\s*(\w+[-/]?\w*)'),
        // Standalone alphanumeric code at the top
        RegExp(r'^([A-Z0-9][-A-Z0-9/]{2,})$'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(cleaned);
        if (match != null) return match.group(1) ?? cleaned;
      }
    }

    // Fallback: first line if short (likely a reference)
    if (lines.first.trim().length <= 20) {
      return lines.first.trim();
    }

    return null;
  }

  /// Extract address from the text lines
  String? _extractAddress(List<String> lines, String? clientNumber) {
    // Skip lines that are the client number
    final addressLines = <String>[];
    var foundClientNumber = clientNumber == null;

    for (final line in lines) {
      final cleaned = line.trim();
      if (cleaned.isEmpty) continue;

      // Skip the client number line
      if (!foundClientNumber && clientNumber != null && cleaned.contains(clientNumber)) {
        foundClientNumber = true;
        continue;
      }

      // Look for address-like content (numbers + street names, city, postal code)
      if (_isAddressLine(cleaned)) {
        addressLines.add(cleaned);
      }
    }

    if (addressLines.isEmpty) {
      // Fallback: take all lines except the first (client number)
      final remaining = lines.skip(1).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      return remaining.isNotEmpty ? remaining.join(', ') : null;
    }

    return addressLines.join(', ');
  }

  bool _isAddressLine(String line) {
    // French address patterns
    final addressPatterns = [
      RegExp(r'\d+\s+(rue|avenue|boulevard|av|bd|allée|place|chemin|impasse|passage|cours|quai)', caseSensitive: false),
      RegExp(r'\d{5}\s+\w+'), // Postal code + city
      RegExp(r'(rue|avenue|boulevard|av|bd|allée|place|chemin|impasse|passage|cours|quai)\s+', caseSensitive: false),
      RegExp(r'(Paris|Lyon|Marseille|Toulouse|Nice|Nantes|Bordeaux|Lille|Strasbourg)', caseSensitive: false),
      RegExp(r'\d+(er|ème|e)?\s+(étage|ét\.?)', caseSensitive: false),
      RegExp(r'(bat|bât|bâtiment|esc|escalier|porte|apt|appt|appartement)', caseSensitive: false),
    ];

    return addressPatterns.any((p) => p.hasMatch(line));
  }

  void dispose() {
    _recognizer.close();
  }
}
