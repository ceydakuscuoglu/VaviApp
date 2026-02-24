import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for interacting with Gemini API to analyze camera frames
class GeminiService {
  // Hardcoded API key - replace with your Gemini API key
  static const String _defaultApiKey =
      '';

  static const String _apiKeyStorageKey = 'gemini_api_key';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Get API key - uses hardcoded key if no key in storage
  Future<String> _getApiKey() async {
    // First try to get from storage (for override capability)
    final storedKey = await _storage.read(key: _apiKeyStorageKey);
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }

    // Use hardcoded key
    if (_defaultApiKey.isNotEmpty) {
      return _defaultApiKey;
    }

    throw Exception(
        'API key not configured. Please set _defaultApiKey in GeminiService.');
  }

  /// Store API key securely (optional override)
  Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyStorageKey, value: apiKey);
  }

  /// Check if API key is set
  Future<bool> hasApiKey() async {
    try {
      final key = await _getApiKey();
      return key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Analyze multiple frames and extract text
  ///
  /// Takes a list of base64-encoded image strings and sends them to Gemini API
  /// Returns the detected text or null if no text is found
  Future<String?> analyzeFrames(List<String> base64Images) async {
    try {
      if (base64Images.isEmpty) {
        throw Exception('No images provided for analysis');
      }

      final apiKey = await _getApiKey();

      // Prepare content parts - convert base64 strings to image data
      final List<Part> parts = [];
      for (final base64Image in base64Images) {
        try {
          // Remove data URL prefix if present
          String imageData = base64Image;
          if (base64Image.contains(',')) {
            imageData = base64Image.split(',').last;
          }

          final decodedBytes = base64Decode(imageData);
          if (decodedBytes.isEmpty) {
            continue; // Skip empty images
          }

          parts.add(DataPart('image/jpeg', decodedBytes));
        } catch (e) {
          // Skip invalid images and continue with others
          print('Error processing image: $e');
          continue;
        }
      }

      if (parts.isEmpty) {
        throw Exception('No valid images to analyze');
      }

      // Add prompt to extract text from images
      final prompt = '''
Analyze these images and extract any text you see, especially room numbers, office numbers, or location identifiers.
Look for text on doors, signs, or labels that might indicate a location (like "A114", "A115", "Office 101", etc.).
Return ONLY the text you find, without any additional explanation. If you see multiple text items, return the most prominent location identifier.
If no clear location text is found, return "NO_TEXT_FOUND".
''';

      parts.insert(0, TextPart(prompt));

      // Try multiple model names as fallback
      final List<String> modelNames = [
        'gemini-2.5-flash',
      ];

      GenerateContentResponse? response;
      Exception? lastException;

      for (final modelName in modelNames) {
        try {
          // Initialize the model
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
          );

          // Generate content with timeout
          final content = Content.multi(parts);
          response = await model.generateContent([content]).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                  'Request timeout. Please check your internet connection and try again.');
            },
          );

          // If successful, break out of loop
          break;
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          // If it's a model not found error, try next model
          if (e.toString().contains('not found') ||
              e.toString().contains('not supported')) {
            print('Model $modelName not available, trying next...');
            continue;
          }
          // For other errors, rethrow
          rethrow;
        }
      }

      if (response == null) {
        throw lastException ?? Exception('Failed to find a working model');
      }

      // Check for blocked content or errors
      if (response.candidates.isEmpty) {
        throw Exception(
            'No response from API. The content may have been blocked or there was an API error.');
      }

      // Extract text from response
      final text = response.text?.trim();

      if (text == null || text.isEmpty || text == 'NO_TEXT_FOUND') {
        return null;
      }

      return text;
    } on Exception {
      rethrow;
    } catch (e) {
      // Handle network errors and other exceptions
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') ||
          errorMessage.contains('socket') ||
          errorMessage.contains('connection')) {
        throw Exception(
            'Network error. Please check your internet connection and try again.');
      } else if (errorMessage.contains('api') ||
          errorMessage.contains('key') ||
          errorMessage.contains('auth')) {
        throw Exception(
            'API authentication error. Please check your API key in settings.');
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timeout. Please try again.');
      } else {
        throw Exception('Failed to analyze frames: ${e.toString()}');
      }
    }
  }

  /// Extract location identifier from detected text
  ///
  /// Tries to extract patterns like "A114", "A115", etc. from the text
  String? extractLocationIdentifier(String? detectedText) {
    if (detectedText == null || detectedText.isEmpty) {
      return null;
    }

    // Try to find patterns like A114, A115, etc.
    // Match patterns like: A114, A-114, A 114, Office A114, Room A114, etc.
    final regex = RegExp(r'[A-Za-z]\s*-?\s*\d+', caseSensitive: false);
    final matches = regex.allMatches(detectedText);

    if (matches.isNotEmpty) {
      // Get the first match and normalize it (remove spaces and hyphens)
      String match = matches.first.group(0) ?? '';
      match = match.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
      return match;
    }

    // If no pattern found, try to extract any alphanumeric sequence
    final alphanumericRegex =
        RegExp(r'[A-Za-z]+\d+|\d+[A-Za-z]+', caseSensitive: false);
    final alphanumericMatches = alphanumericRegex.allMatches(detectedText);

    if (alphanumericMatches.isNotEmpty) {
      return alphanumericMatches.first.group(0)?.toUpperCase();
    }

    // Return the original text if no pattern matches
    return detectedText.trim().toUpperCase();
  }
}
