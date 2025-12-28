import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:string_similarity/string_similarity.dart';
import '../models/node.dart';

/// Service for handling voice input and matching to nodes
class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  Completer<String?>? _listeningCompleter;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final available = await _speech.initialize(
        onError: (error) {
          _isInitialized = false;
          _isListening = false;
          if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
            _listeningCompleter!.complete(null);
          }
        },
        onStatus: (status) {
          // Handle different statuses
          if (status == 'done' || status == 'notListening' || status == 'listening') {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              // Only complete if we don't have a result yet
              if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
                // Give it a moment to see if we get a final result
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
                    _listeningCompleter!.complete(null);
                  }
                });
              }
            }
          }
        },
      );
      _isInitialized = available;
      return available;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Check if a locale is available
  Future<bool> isLocaleAvailable(String localeId) async {
    if (!_isInitialized) {
      await initialize();
    }
    final locales = await _speech.locales();
    return locales.any((locale) => locale.localeId == localeId);
  }

  /// Check and request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start listening for voice input
  /// Returns the recognized text or null if error
  Future<String?> startListening({
    String localeId = 'en_US',
    Duration? listenDuration,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        return null;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    // Cancel any existing completer
    if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
      _listeningCompleter!.complete(null);
    }

    _listeningCompleter = Completer<String?>();
    String? recognizedText;
    String? lastPartialResult;

    // Get available locales and select Turkish first
    final locales = await _speech.locales();
    String actualLocaleId = localeId;
    
    // Log all available locales for debugging
    print('Available speech recognition locales:');
    for (var locale in locales) {
      print('  - ${locale.localeId}: ${locale.name}');
    }
    
    // Prioritize English locale (since Turkish is not available)
    final englishLocales = locales.where((locale) => 
      locale.localeId.startsWith('en')).toList();
    
    if (englishLocales.isNotEmpty) {
      // Prefer en_US, then en_GB, then any English locale
      final preferredEn = englishLocales.firstWhere(
        (locale) => locale.localeId == 'en_US',
        orElse: () => englishLocales.firstWhere(
          (locale) => locale.localeId == 'en_GB',
          orElse: () => englishLocales.first,
        ),
      );
      actualLocaleId = preferredEn.localeId;
      print('Using English locale: $actualLocaleId');
    } else {
      // If English is not available, check if requested locale is available
      if (await isLocaleAvailable(localeId)) {
        actualLocaleId = localeId;
        print('Using requested locale: $actualLocaleId');
      } else {
        // Avoid Asian locales (Chinese, Japanese, Korean, Thai, Vietnamese)
        final nonAsianLocales = locales.where((locale) => 
          !locale.localeId.startsWith('zh') && 
          !locale.localeId.startsWith('ja') &&
          !locale.localeId.startsWith('ko') &&
          !locale.localeId.startsWith('th') &&
          !locale.localeId.startsWith('vi')
        ).toList();
        if (nonAsianLocales.isNotEmpty) {
          actualLocaleId = nonAsianLocales.first.localeId;
          print('English not available, using fallback locale: $actualLocaleId');
        } else {
          print('WARNING: Only Asian locales available, this may cause issues!');
          if (locales.isNotEmpty) {
            actualLocaleId = locales.first.localeId;
          }
        }
      }
    }
    
    print('Final selected locale: $actualLocaleId');

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          // Store partial results as they come in
          if (result.recognizedWords.isNotEmpty) {
            lastPartialResult = result.recognizedWords;
          }
          
          // When we get a final result, use it
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            recognizedText = result.recognizedWords;
            _isListening = false;
            if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
              _listeningCompleter!.complete(recognizedText);
            }
          }
        },
        localeId: actualLocaleId,
        listenFor: listenDuration ?? const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 7),
        partialResults: true,
        listenMode: stt.ListenMode.dictation, // Use dictation mode for better continuous recognition
        cancelOnError: false,
        onSoundLevelChange: (level) {
          // Optional: can be used for visual feedback
        },
      );

      // Wait for the result with a timeout
      final timeoutDuration = Duration(
        seconds: (listenDuration ?? const Duration(seconds: 15)).inSeconds + 3,
      );
      
      try {
        recognizedText = await _listeningCompleter!.future.timeout(
          timeoutDuration,
          onTimeout: () {
            // If we have a partial result, use it
            if (lastPartialResult != null && lastPartialResult!.isNotEmpty) {
              return lastPartialResult;
            }
            // Otherwise stop listening and return null
            if (_isListening) {
              stopListening();
            }
            return null;
          },
        );
      } catch (e) {
        // If we have a partial result, use it
        if (lastPartialResult != null && lastPartialResult!.isNotEmpty) {
          recognizedText = lastPartialResult;
        } else {
          if (_isListening) {
            stopListening();
          }
          return null;
        }
      }
    } catch (e) {
      _isListening = false;
      if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
        _listeningCompleter!.complete(null);
      }
      // If we have a partial result, use it even on error
      if (lastPartialResult != null && lastPartialResult!.isNotEmpty) {
        return lastPartialResult;
      }
      return null;
    }

    return recognizedText;
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
        _listeningCompleter!.complete(null);
      }
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Extract location code from natural language text
  /// Examples: "I want to go A114" -> "A114"
  ///           "A114'e gitmek istiyorum" -> "A114"
  ///           "Take me to B205" -> "B205"
  ///           "A114" -> "A114"
  String? extractLocationCode(String text) {
    if (text.isEmpty) return null;

    // Normalize text: remove extra spaces, convert to uppercase
    // Also handle Turkish characters that might be in the text
    final normalized = text.trim().toUpperCase();

    // Pattern to match room codes like A114, B205, C301, etc.
    // Matches: letter(s) followed by digits
    // This works for both English and Turkish since location codes are alphanumeric
    final roomCodePattern = RegExp(r'\b([A-Z]+)\s*(\d+)\b');
    final match = roomCodePattern.firstMatch(normalized);

    if (match != null) {
      // Combine letter and number parts
      final letterPart = match.group(1) ?? '';
      final numberPart = match.group(2) ?? '';
      return '$letterPart$numberPart';
    }

    // Fallback: try to find any pattern that looks like a room code
    // This handles cases where speech recognition might have added spaces
    final fallbackPattern = RegExp(r'([A-Z])\s*(\d{2,4})');
    final fallbackMatch = fallbackPattern.firstMatch(normalized);
    if (fallbackMatch != null) {
      return '${fallbackMatch.group(1)}${fallbackMatch.group(2)}';
    }

    return null;
  }

  /// Find the best matching node from the recognized text
  /// Uses fuzzy matching to find nodes that contain the location code
  Node? findMatchingNode(String recognizedText, List<Node> availableNodes) {
    final locationCode = extractLocationCode(recognizedText);
    if (locationCode == null) return null;

    // Filter nodes to exclude corridors and connections
    final searchableNodes = availableNodes.where((node) {
      final type = node.type.toLowerCase();
      return type != 'corridor' && type != 'connection';
    }).toList();

    if (searchableNodes.isEmpty) return null;

    Node? bestMatch;
    double bestScore = 0.0;

    for (final node in searchableNodes) {
      final nodeName = node.name.toUpperCase();
      
      // Check if location code is in the node name
      if (nodeName.contains(locationCode)) {
        // Calculate similarity score
        final score = StringSimilarity.compareTwoStrings(
          locationCode,
          nodeName,
        );
        
        // Also check if the location code matches exactly within the name
        // (e.g., "A114" in "FİZİK LAB - A111" should have lower score than exact match)
        if (nodeName.contains(' - $locationCode') || 
            nodeName.endsWith(locationCode) ||
            nodeName.startsWith('$locationCode ')) {
          // Exact match in name gets higher priority
          final exactScore = score * 1.5;
          if (exactScore > bestScore) {
            bestScore = exactScore;
            bestMatch = node;
          }
        } else if (score > bestScore) {
          bestScore = score;
          bestMatch = node;
        }
      }
    }

    // If we found a match with reasonable score, return it
    // Lower threshold for partial matches
    if (bestMatch != null && bestScore > 0.1) {
      return bestMatch;
    }

    // If no match found, try fuzzy matching on the full recognized text
    // This helps with cases where extraction didn't work perfectly
    bestMatch = null;
    bestScore = 0.0;

    for (final node in searchableNodes) {
      final score = StringSimilarity.compareTwoStrings(
        recognizedText.toUpperCase(),
        node.name.toUpperCase(),
      );
      if (score > bestScore && score > 0.3) {
        bestScore = score;
        bestMatch = node;
      }
    }

    return bestMatch;
  }

  /// Dispose resources
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _isListening = false;
    _isInitialized = false;
  }
}

