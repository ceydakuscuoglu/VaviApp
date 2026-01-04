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
          // Note: We don't complete the completer here anymore to avoid race conditions
          // The completer is only completed in onResult callbacks or timeout handlers
          if (status == 'done' || status == 'notListening' || status == 'listening') {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              // Don't complete here - let the timeout or result handler do it
              // This prevents premature completion when waiting for user input
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
    Timer? pauseTimer;

    // Get available locales and select Turkish first
    final locales = await _speech.locales();
    String actualLocaleId = localeId;
    
    // Log all available locales for debugging
    /*print('Available speech recognition locales:');
    for (var locale in locales) {
      print('  - ${locale.localeId}: ${locale.name}');
    }*/
    
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
            print('Partial result: ${result.recognizedWords}');
            
            // Cancel any existing pause timer since we got new speech
            pauseTimer?.cancel();
            pauseTimer = null;
          }
          
          // When we get a final result, complete immediately
          // The pauseFor parameter already handled waiting for silence
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            recognizedText = result.recognizedWords;
            print('Final result: $recognizedText');
            
            // Cancel any pause timer since we have a final result
            pauseTimer?.cancel();
            
            // Complete immediately - pauseFor already waited 7 seconds
            if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
              _isListening = false;
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
      // Add extra time for the pause period (7 seconds) plus buffer
      final timeoutDuration = Duration(
        seconds: (listenDuration ?? const Duration(seconds: 15)).inSeconds + 10, // Increased to account for pause period
      );
      
      try {
        recognizedText = await _listeningCompleter!.future.timeout(
          timeoutDuration,
          onTimeout: () {
            print('Timeout occurred. Last partial: $lastPartialResult, Final: $recognizedText');
            // If we have a recognized text but timer hasn't fired yet, use it immediately
            if (recognizedText != null && recognizedText!.isNotEmpty) {
              pauseTimer?.cancel();
              _isListening = false;
              return recognizedText;
            }
            // If we have a partial result, use it
            if (lastPartialResult != null && lastPartialResult!.isNotEmpty) {
              pauseTimer?.cancel();
              _isListening = false;
              return lastPartialResult;
            }
            // Otherwise stop listening and return null
            pauseTimer?.cancel();
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
      pauseTimer?.cancel();
      _isListening = false;
      if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
        _listeningCompleter!.complete(null);
      }
      // If we have a partial result, use it even on error
      if (lastPartialResult != null && lastPartialResult!.isNotEmpty) {
        return lastPartialResult;
      }
      return null;
    } finally {
      pauseTimer?.cancel();
    }

    return recognizedText;
  }

  /// Stop listening
  /// [completeCompleter] - if true, completes the completer with null. 
  /// Set to false when you want to wait for timeout instead (e.g., in listenForYesNo)
  Future<void> stopListening({bool completeCompleter = true}) async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      if (completeCompleter && _listeningCompleter != null && !_listeningCompleter!.isCompleted) {
        _listeningCompleter!.complete(null);
      }
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Normalize text by removing ordinal suffixes, filler words, and normalizing spacing
  /// Examples: "a 400 12th" -> "A 400", "take me to b205" -> "B205"
  String _normalizeText(String text) {
    if (text.isEmpty) return text;

    // Convert to uppercase and trim
    String normalized = text.trim().toUpperCase();

    // Remove ordinal suffixes (th, st, nd, rd) from numbers
    // e.g., "400th" -> "400", "12th" -> "12"
    normalized = normalized.replaceAll(RegExp(r'(\d+)(ST|ND|RD|TH)\b'), r'$1');

    // Remove common filler words that don't contribute to location codes
    final fillerWords = [
      'THE', 'TO', 'GO', 'TAKE', 'ME', 'I', 'WANT', 'ROOM', 'LOCATION',
      'PLACE', 'DESTINATION', 'FROM', 'AT', 'IN', 'ON', 'A', 'AN',
      'TRANSIT', 'OFFICE', 'LAB', 'LABORATORY', 'FLOOR', 'LEVEL',
      'BUILDING', 'WING', 'SECTION', 'AREA', 'ZONE', 'BLOCK',
      'NAVIGATE', 'NAVIGATION', 'GUIDE', 'SHOW', 'FIND', 'SEARCH'
    ];
    for (final word in fillerWords) {
      // Remove word with word boundaries to avoid partial matches
      normalized = normalized.replaceAll(RegExp(r'\b' + word + r'\b'), '');
    }

    // Normalize spacing: replace multiple spaces with single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  /// Try to correct common speech recognition misrecognitions
  /// Examples: "8300" -> ["A300", "8300"], "8300 12th" -> ["A312", "A300", "8300"]
  List<String> _generateLocationCodeCandidates(String normalized) {
    final candidates = <String>[];
    
    // Pattern 1: Handle "8300 12th" -> "A312" case
    // Look for patterns like "8XXX YYth" where 8 might be A and we combine the remaining parts
    final combinedPattern = RegExp(r'\b(8)(\d{2,3})\s+(\d{1,2})(?:TH|ST|ND|RD)?\b');
    final combinedMatches = combinedPattern.allMatches(normalized);
    
    for (final match in combinedMatches) {
      final middleDigits = match.group(2) ?? ''; // "300"
      final lastDigits = match.group(3) ?? ''; // "12"
      
      // Try combining: "8300 12th" -> "A312" (A + 300+12)
      try {
        final middleNum = int.parse(middleDigits);
        final lastNum = int.parse(lastDigits);
        final combined = middleNum + lastNum;
        
        // Only if combined makes sense (2-4 digits total)
        if (combined >= 10 && combined <= 9999) {
          final combinedStr = combined.toString();
          // Prefer 3-digit codes (most common room numbers like A312)
          candidates.add('A$combinedStr');
        }
      } catch (e) {
        // Ignore parse errors
      }
      
      // Also try just "A" + middle digits: "8300 12th" -> "A300"
      candidates.add('A$middleDigits');
    }
    
    // Pattern 2: Try to find number patterns that might be misrecognized letters
    // Common misrecognitions: 8→A, 2→A, 0→O, 1→I, 5→S, 3→E
    final numberStartPattern = RegExp(r'\b(\d{3,4})(?:\s+(\d{1,2}))?(?:TH|ST|ND|RD)?\b');
    final numberMatches = numberStartPattern.allMatches(normalized);
    
    for (final match in numberMatches) {
      final firstNumber = match.group(1) ?? '';
      final secondNumber = match.group(2);
      
      // If number starts with 8, try replacing with A (common misrecognition)
      if (firstNumber.startsWith('8')) {
        final corrected = 'A${firstNumber.substring(1)}';
        candidates.add(corrected);
        
        // For 4-digit numbers starting with 8, also try number digit misrecognitions
        // e.g., "8300" could be "A320" (8→A, and 0→2 in the middle)
        if (firstNumber.length == 4) {
          final digits = firstNumber.substring(1); // "300"
          
          // Try common digit misrecognitions within the number
          // 0→2, 0→4, 0→6, 0→8 (common misrecognitions)
          // 2→0, 4→0, 6→0, 8→0 (reverse)
          final digitVariations = <String>[];
          
          // Try replacing each 0 with 2, 4, 6, 8
          for (int i = 0; i < digits.length; i++) {
            if (digits[i] == '0') {
              digitVariations.add(digits.substring(0, i) + '2' + digits.substring(i + 1));
              digitVariations.add(digits.substring(0, i) + '4' + digits.substring(i + 1));
              digitVariations.add(digits.substring(0, i) + '6' + digits.substring(i + 1));
              digitVariations.add(digits.substring(0, i) + '8' + digits.substring(i + 1));
            }
            // Also try replacing 2, 4, 6, 8 with 0
            if (digits[i] == '2' || digits[i] == '4' || digits[i] == '6' || digits[i] == '8') {
              digitVariations.add(digits.substring(0, i) + '0' + digits.substring(i + 1));
            }
          }
          
          // Add variations as candidates
          for (final variation in digitVariations) {
            if (RegExp(r'^\d{3}$').hasMatch(variation)) {
              candidates.add('A$variation');
            }
          }
        }
        
        // If there's a second number and first number is 4 digits starting with 8,
        // try combining the last 3 digits with the second number
        // e.g., "8300 12" -> "A312" (A + 300+12)
        if (secondNumber != null && firstNumber.length == 4) {
          try {
            final lastThreeDigits = int.parse(firstNumber.substring(1)); // "300"
            final secondNum = int.parse(secondNumber); // "12"
            final combined = lastThreeDigits + secondNum; // 300 + 12 = 312
            // Only if combined makes sense (2-4 digits)
            if (combined >= 10 && combined <= 9999) {
              candidates.add('A$combined');
            }
          } catch (e) {
            // Ignore parse errors
          }
        }
      }
      
      // If number starts with 2, try replacing with A (2 might be misrecognized as A)
      if (firstNumber.startsWith('2') && firstNumber.length >= 3) {
        final corrected = 'A${firstNumber.substring(1)}';
        candidates.add(corrected);
      }
      
      // If number starts with 1, try replacing with I (1 might be misrecognized as I)
      if (firstNumber.startsWith('1') && firstNumber.length >= 3) {
        final corrected = 'I${firstNumber.substring(1)}';
        candidates.add(corrected);
      }
      
      // If number starts with 5, try replacing with S (5 might be misrecognized as S)
      if (firstNumber.startsWith('5') && firstNumber.length >= 3) {
        final corrected = 'S${firstNumber.substring(1)}';
        candidates.add(corrected);
      }
      
      // Also try the original number as-is (might be correct)
      if (firstNumber.length >= 3) {
        candidates.add(firstNumber);
      }
    }
    
    // Pattern 2: Standard letter + number patterns
    final letterNumberPattern = RegExp(r'\b([A-Z]+)\s*(\d{2,4})\b');
    final letterMatches = letterNumberPattern.allMatches(normalized);
    
    for (final match in letterMatches) {
      final letterPart = match.group(1) ?? '';
      final numberPart = match.group(2) ?? '';
      candidates.add('$letterPart$numberPart');
    }
    
    // Pattern 3: Try correcting numbers that might be letters
    // e.g., "8300" -> try "A300", "A320", "A340", etc. (handle digit misrecognitions too)
    final allNumbersPattern = RegExp(r'\b(\d{3,4})\b');
    final allNumberMatches = allNumbersPattern.allMatches(normalized);
    
    for (final match in allNumberMatches) {
      final number = match.group(1) ?? '';
      if (number.length >= 3) {
        // 8→A misrecognition
        if (number.startsWith('8')) {
          final numberPart = number.substring(1);
          candidates.add('A$numberPart');
          
          // For 4-digit numbers, also try digit variations
          // e.g., "8300" -> "A320", "A340", "A360", "A380" (0→2,4,6,8)
          if (number.length == 4) {
            final digits = numberPart;
            // Try replacing 0 with 2, 4, 6, 8 in each position
            for (int i = 0; i < digits.length; i++) {
              if (digits[i] == '0') {
                candidates.add('A${digits.substring(0, i)}2${digits.substring(i + 1)}');
                candidates.add('A${digits.substring(0, i)}4${digits.substring(i + 1)}');
                candidates.add('A${digits.substring(0, i)}6${digits.substring(i + 1)}');
                candidates.add('A${digits.substring(0, i)}8${digits.substring(i + 1)}');
              }
              // Also try replacing 2, 4, 6, 8 with 0
              if (digits[i] == '2' || digits[i] == '4' || digits[i] == '6' || digits[i] == '8') {
                candidates.add('A${digits.substring(0, i)}0${digits.substring(i + 1)}');
              }
            }
          }
        }
        // 2→A misrecognition
        if (number.startsWith('2')) {
          candidates.add('A${number.substring(1)}');
        }
        // 1→I misrecognition
        if (number.startsWith('1')) {
          candidates.add('I${number.substring(1)}');
        }
        // 5→S misrecognition
        if (number.startsWith('5')) {
          candidates.add('S${number.substring(1)}');
        }
        // 0→O misrecognition
        if (number.startsWith('0')) {
          candidates.add('O${number.substring(1)}');
        }
      }
    }
    
    return candidates;
  }

  /// Extract location code from natural language text
  /// Examples: "I want to go A114" -> "A114"
  ///           "A114'e gitmek istiyorum" -> "A114"
  ///           "Take me to B205" -> "B205"
  ///           "a 400 12th" -> "A400"
  ///           "a400 12" -> "A400"
  ///           "8300 12th" -> "A312" (handles misrecognition)
  ///           "A200 Transit" -> "A200" (prioritizes location code over extra words)
  String? extractLocationCode(String text) {
    if (text.isEmpty) return null;

    // First normalize the text (removes filler words like "Transit")
    final normalized = _normalizeText(text);

    // Generate candidate location codes including misrecognition corrections
    final candidates = _generateLocationCodeCandidates(normalized);
    
    // Prioritize candidates: prefer single letter + 3-4 digit codes (most common room format)
    // Sort candidates by preference: single letter > multiple letters, longer numbers > shorter
    candidates.sort((a, b) {
      final aMatch = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(a);
      final bMatch = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(b);
      
      if (aMatch == null || bMatch == null) return 0;
      
      final aLetters = aMatch.group(1)!.length;
      final bLetters = bMatch.group(1)!.length;
      final aDigits = aMatch.group(2)!.length;
      final bDigits = bMatch.group(2)!.length;
      
      // Prefer single letter codes
      if (aLetters != bLetters) {
        return aLetters.compareTo(bLetters);
      }
      // Prefer longer number codes (3-4 digits are more likely to be room numbers)
      return bDigits.compareTo(aDigits);
    });
    
    // Try candidates in order of preference
    for (final candidate in candidates) {
      // Validate candidate format (letter(s) + 2-4 digits)
      if (RegExp(r'^[A-Z]{1,2}\d{2,4}$').hasMatch(candidate)) {
        return candidate;
      }
    }

    // Fallback: Find all potential location code patterns
    // Pattern 1: letter(s) followed by 2-4 digits (most common room code pattern)
    final primaryPattern = RegExp(r'\b([A-Z]+)\s*(\d{2,4})\b');
    final primaryMatches = primaryPattern.allMatches(normalized).toList();

    if (primaryMatches.isNotEmpty) {
      // If multiple matches, prefer the one that looks most like a room code
      // Prioritize: single letter + 2-4 digits > multiple letters + 2-4 digits
      Match? bestMatch;
      for (final match in primaryMatches) {
        final letterPart = match.group(1) ?? '';
        final numberPart = match.group(2) ?? '';
        
        // Prefer single letter codes (most common)
        if (letterPart.length == 1 && (numberPart.length >= 2 && numberPart.length <= 4)) {
          return '$letterPart$numberPart';
        }
        
        // Keep track of best match if no single letter found
        if (bestMatch == null || letterPart.length < (bestMatch.group(1)?.length ?? 999)) {
          bestMatch = match;
        }
      }
      
      // Return the best match found
      if (bestMatch != null) {
        final letterPart = bestMatch.group(1) ?? '';
        final numberPart = bestMatch.group(2) ?? '';
        return '$letterPart$numberPart';
      }
    }

    // Pattern 2: letter(s) followed by any digits (fallback for edge cases)
    final fallbackPattern = RegExp(r'\b([A-Z]+)\s*(\d+)\b');
    final fallbackMatches = fallbackPattern.allMatches(normalized).toList();

    if (fallbackMatches.isNotEmpty) {
      // When multiple numbers are present, prefer the first/longer one
      // This handles cases like "a400 12" where we want "A400" not "A12"
      Match? bestMatch;
      int maxNumberLength = 0;
      
      for (final match in fallbackMatches) {
        final letterPart = match.group(1) ?? '';
        final numberPart = match.group(2) ?? '';
        final numberLength = numberPart.length;
        
        // Prefer longer numbers (more likely to be the room number)
        // and single letter prefixes
        if (numberLength > maxNumberLength || 
            (numberLength == maxNumberLength && letterPart.length == 1)) {
          maxNumberLength = numberLength;
          bestMatch = match;
        }
      }
      
      if (bestMatch != null) {
        final letterPart = bestMatch.group(1) ?? '';
        final numberPart = bestMatch.group(2) ?? '';
        // Only return if number is at least 2 digits (single digits are likely not room codes)
        if (numberPart.length >= 2) {
          return '$letterPart$numberPart';
        }
      }
    }

    // Pattern 3: Single letter followed by digits (handles spacing variations)
    final singleLetterPattern = RegExp(r'([A-Z])\s*(\d{2,4})');
    final singleLetterMatch = singleLetterPattern.firstMatch(normalized);
    if (singleLetterMatch != null) {
      return '${singleLetterMatch.group(1)}${singleLetterMatch.group(2)}';
    }

    return null;
  }

  /// Find the best matching node from the recognized text
  /// Uses fuzzy matching to find nodes that contain the location code
  /// Tries multiple extraction strategies if the first one fails
  Node? findMatchingNode(String recognizedText, List<Node> availableNodes) {
    // Filter nodes to exclude corridors and connections
    final searchableNodes = availableNodes.where((node) {
      final type = node.type.toLowerCase();
      return type != 'corridor' && type != 'connection';
    }).toList();

    if (searchableNodes.isEmpty) return null;

    // Strategy 1: Try extracting location code and all candidates (including misrecognition corrections)
    final normalized = _normalizeText(recognizedText);
    final candidates = _generateLocationCodeCandidates(normalized);
    
    // Also get the standard extraction
    final locationCode = extractLocationCode(recognizedText);
    if (locationCode != null && !candidates.contains(locationCode)) {
      candidates.insert(0, locationCode); // Prioritize standard extraction
    }
    
    // Try all candidates in order
    for (final candidate in candidates) {
      // Validate candidate format
      if (RegExp(r'^[A-Z]{1,2}\d{2,4}$').hasMatch(candidate)) {
        final match = _findMatchByLocationCode(candidate, searchableNodes);
        if (match != null) return match;
      }
    }
    
    // Strategy 2: Try standard extraction if candidates didn't work
    Node? bestMatch;
    if (locationCode != null) {
      bestMatch = _findMatchByLocationCode(locationCode, searchableNodes);
      if (bestMatch != null) return bestMatch;
    }

    // Strategy 3: Try extraction with different normalization (without removing filler words)
    // Sometimes filler words might help with context
    final normalizedWithoutFillerRemoval = recognizedText.trim().toUpperCase()
        .replaceAll(RegExp(r'(\d+)(ST|ND|RD|TH)\b'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final altLocationCode = _extractLocationCodeFromNormalized(normalizedWithoutFillerRemoval);
    if (altLocationCode != null && altLocationCode != locationCode) {
      bestMatch = _findMatchByLocationCode(altLocationCode, searchableNodes);
      if (bestMatch != null) return bestMatch;
    }

    // Strategy 3: Try fuzzy matching on normalized recognized text
    final normalizedText = _normalizeText(recognizedText);
    bestMatch = _findMatchByFuzzyText(normalizedText, searchableNodes);
    if (bestMatch != null) return bestMatch;

    // Strategy 4: Try fuzzy matching on original recognized text
    bestMatch = _findMatchByFuzzyText(recognizedText.toUpperCase(), searchableNodes);
    if (bestMatch != null) return bestMatch;

    return null;
  }

  /// Find match by location code with improved scoring
  Node? _findMatchByLocationCode(String locationCode, List<Node> searchableNodes) {
    Node? bestMatch;
    double bestScore = 0.0;

    for (final node in searchableNodes) {
      final nodeName = node.name.toUpperCase();
      
      // Check if location code is in the node name
      if (nodeName.contains(locationCode)) {
        // Calculate base similarity score
        double score = StringSimilarity.compareTwoStrings(
          locationCode,
          nodeName,
        );
        
        // Check for exact match patterns (higher priority)
        if (nodeName == locationCode) {
          // Perfect match gets highest priority
          score = 1.0;
        } else if (nodeName.contains(' - $locationCode') || 
            nodeName.endsWith(locationCode) ||
            nodeName.startsWith('$locationCode ')) {
          // Location code at start/end or after " - " gets high priority
          score = score * 1.5;
        } else if (nodeName.contains(' $locationCode ') || 
                   nodeName.contains('$locationCode ')) {
          // Location code appears as a word gets medium-high priority
          score = score * 1.2;
        } else {
          // Location code appears somewhere in the name (partial match)
          // Give it a boost but not as much
          score = score * 1.1;
        }
        
        if (score > bestScore) {
          bestScore = score;
          bestMatch = node;
        }
      }
    }

    // Return match if score is reasonable (lowered threshold for better matching)
    if (bestMatch != null && bestScore > 0.05) {
      return bestMatch;
    }

    return null;
  }

  /// Extract location code from already normalized text (internal helper)
  String? _extractLocationCodeFromNormalized(String normalized) {
    // Pattern 1: letter(s) followed by 2-4 digits
    final primaryPattern = RegExp(r'\b([A-Z]+)\s*(\d{2,4})\b');
    final primaryMatches = primaryPattern.allMatches(normalized).toList();

    if (primaryMatches.isNotEmpty) {
      Match? bestMatch;
      for (final match in primaryMatches) {
        final letterPart = match.group(1) ?? '';
        if (letterPart.length == 1) {
          return '${match.group(1)}${match.group(2)}';
        }
        if (bestMatch == null || letterPart.length < (bestMatch.group(1)?.length ?? 999)) {
          bestMatch = match;
        }
      }
      if (bestMatch != null) {
        return '${bestMatch.group(1)}${bestMatch.group(2)}';
      }
    }

    // Pattern 2: letter(s) followed by any digits
    final fallbackPattern = RegExp(r'\b([A-Z]+)\s*(\d+)\b');
    final fallbackMatches = fallbackPattern.allMatches(normalized).toList();

    if (fallbackMatches.isNotEmpty) {
      Match? bestMatch;
      int maxNumberLength = 0;
      for (final match in fallbackMatches) {
        final numberLength = (match.group(2)?.length ?? 0);
        if (numberLength > maxNumberLength) {
          maxNumberLength = numberLength;
          bestMatch = match;
        }
      }
      if (bestMatch != null && (bestMatch.group(2)?.length ?? 0) >= 2) {
        return '${bestMatch.group(1)}${bestMatch.group(2)}';
      }
    }

    return null;
  }

  /// Find match using fuzzy text matching
  Node? _findMatchByFuzzyText(String text, List<Node> searchableNodes) {
    Node? bestMatch;
    double bestScore = 0.0;

    for (final node in searchableNodes) {
      final nodeName = node.name.toUpperCase();
      
      // Try full string similarity
      final fullScore = StringSimilarity.compareTwoStrings(text, nodeName);
      
      // Also try partial matching - check if location code from text appears in node name
      final locationCode = extractLocationCode(text);
      double partialScore = 0.0;
      if (locationCode != null && nodeName.contains(locationCode)) {
        // If location code is found, give it a boost
        partialScore = 0.5;
      }
      
      final score = fullScore > partialScore ? fullScore : partialScore;
      
      if (score > bestScore && score > 0.2) {
        bestScore = score;
        bestMatch = node;
      }
    }

    // Only return if we found a match with reasonable confidence (lowered from 0.3 to 0.2)
    return (bestScore > 0.2) ? bestMatch : null;
  }

  /// Listen for yes/no response
  /// Returns true for yes, false for no, null if unclear
  Future<bool?> listenForYesNo({
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
    String? pendingResult; // Store result that came during grace period
    final DateTime listenStartTime = DateTime.now();
    const minWaitDuration = Duration(milliseconds: 800); // Reduced to 0.8 seconds - just enough to prevent TTS echo, allows immediate user responses

    // Get available locales
    final locales = await _speech.locales();
    String actualLocaleId = localeId;
    
    // Prioritize English for yes/no recognition
    final englishLocales = locales.where((locale) => 
      locale.localeId.startsWith('en')).toList();
    
    if (englishLocales.isNotEmpty) {
      final preferredEn = englishLocales.firstWhere(
        (locale) => locale.localeId == 'en_US',
        orElse: () => englishLocales.first,
      );
      actualLocaleId = preferredEn.localeId;
    } else if (await isLocaleAvailable(localeId)) {
      actualLocaleId = localeId;
    }

    // Calculate timeout duration first - we'll use this for listenFor
    final timeoutDuration = Duration(
      seconds: (listenDuration ?? const Duration(seconds: 12)).inSeconds + 3, // Timeout after listen duration + buffer
    );

    try {
      _isListening = true;
      print('listenForYesNo: Starting speech recognition with locale $actualLocaleId, listenFor: ${timeoutDuration.inSeconds}s');
      try {
        await _speech.listen(
          onResult: (result) {
            final timeSinceStart = DateTime.now().difference(listenStartTime);
            
            if (result.recognizedWords.isNotEmpty) {
              // If result comes during grace period, store it as pending
              if (timeSinceStart < minWaitDuration) {
                // Check if it's a valid yes/no response
                final testResult = _parseYesNo(result.recognizedWords);
                if (testResult != null) {
                  // Valid yes/no response - store as pending
                  pendingResult = result.recognizedWords;
                  print('listenForYesNo: Storing pending result (${timeSinceStart.inMilliseconds}ms < ${minWaitDuration.inMilliseconds}ms): ${result.recognizedWords}');
                } else {
                  print('listenForYesNo: Ignoring early invalid result (${timeSinceStart.inMilliseconds}ms): ${result.recognizedWords}');
                }
                return;
              }
              
              // After grace period, accept results normally
              lastPartialResult = result.recognizedWords;
              print('listenForYesNo partial result (${timeSinceStart.inMilliseconds}ms): ${result.recognizedWords}');
            }
            
            // Handle empty final results (can occur when pauseFor triggers) - ignore and continue waiting
            if (result.finalResult && result.recognizedWords.isEmpty) {
              print('listenForYesNo: Ignoring empty final result (likely from pauseFor) - continuing to wait');
              return; // Don't complete completer, continue waiting
            }
            
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              // Only accept final results if enough time has passed
              if (timeSinceStart >= minWaitDuration) {
                recognizedText = result.recognizedWords;
                print('listenForYesNo final result (${timeSinceStart.inMilliseconds}ms): $recognizedText');
                _isListening = false;
                if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
                  _listeningCompleter!.complete(recognizedText);
                }
              } else {
                // If it's a valid yes/no and came close to grace period end, accept it immediately
                final testResult = _parseYesNo(result.recognizedWords);
                if (testResult != null && timeSinceStart.inMilliseconds >= minWaitDuration.inMilliseconds - 300) {
                  // Valid response within 300ms of grace period end - accept it immediately
                  recognizedText = result.recognizedWords;
                  print('listenForYesNo: Accepting final result near grace period end (${timeSinceStart.inMilliseconds}ms): $recognizedText');
                  _isListening = false;
                  if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
                    _listeningCompleter!.complete(recognizedText);
                  }
                } else if (testResult != null) {
                  // Valid yes/no response during grace period - store as pending (will be used after grace period)
                  pendingResult = result.recognizedWords;
                  print('listenForYesNo: Storing valid final result as pending (${timeSinceStart.inMilliseconds}ms): ${result.recognizedWords}');
                } else {
                  print('listenForYesNo: Ignoring final result that came too early (${timeSinceStart.inMilliseconds}ms): ${result.recognizedWords}');
                }
              }
            }
          },
          localeId: actualLocaleId,
          listenFor: timeoutDuration, // Use full timeout duration to ensure it stays active
          pauseFor: Duration(seconds: timeoutDuration.inSeconds + 5), // Longer than listenFor to prevent early pausing
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
        );
        print('listenForYesNo: Speech recognition started, isListening: $_isListening');
      } catch (listenError) {
        print('listenForYesNo: Error starting speech recognition: $listenError');
        _isListening = false;
        // Don't complete completer here - let it timeout naturally
        // This ensures we still wait the full duration even if listen fails
      }
      
      try {
        // Wait for minimum duration before checking for results (grace period)
        await Future.delayed(minWaitDuration);
        
        // After grace period, check if we have a pending valid result
        if (pendingResult != null && pendingResult!.isNotEmpty) {
          final testResult = _parseYesNo(pendingResult!);
          if (testResult != null) {
            // We had a valid yes/no response during grace period - use it now
            recognizedText = pendingResult;
            print('listenForYesNo: Using pending result after grace period: $recognizedText');
            _isListening = false;
            if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
              _listeningCompleter!.complete(recognizedText);
            }
            // Return immediately since we have the result
            final result = _parseYesNo(recognizedText!);
            print('listenForYesNo: Parsed result from pending: $result');
            return result;
          }
        }
        
        // Wait for completer to complete (either with result or timeout)
        // The timeout duration is from the start of listening, so we need to account for grace period
        final remainingTimeout = timeoutDuration - minWaitDuration;
        print('listenForYesNo: Waiting for response with timeout of ${remainingTimeout.inSeconds}s (total: ${timeoutDuration.inSeconds}s, grace: ${minWaitDuration.inMilliseconds}ms)');
        print('listenForYesNo: Completer state - isCompleted: ${_listeningCompleter!.isCompleted}');
        
        // Wait for the full timeout duration, regardless of when completer completes
        // We use a combination of waiting for the completer AND ensuring we wait the full duration
        final completerStartTime = DateTime.now();
        String? completerResult;
        
        try {
          completerResult = await _listeningCompleter!.future.timeout(
            remainingTimeout,
            onTimeout: () {
              // Timeout occurred - return null to indicate no result
              return null;
            },
          );
        } catch (e) {
          print('listenForYesNo: Exception waiting for completer future: $e');
          completerResult = null;
        }
        
        // Calculate how long we've waited
        final timeWaited = DateTime.now().difference(completerStartTime);
        
        // If we got a valid result, use it immediately
        if (completerResult != null && completerResult.isNotEmpty) {
          recognizedText = completerResult;
          print('listenForYesNo: Got result from completer after ${timeWaited.inSeconds}s: $recognizedText');
        } else {
          // If completer completed early with null, we still need to wait the full duration
          // This ensures users have the full time to respond even if speech recognition stops
          if (timeWaited < remainingTimeout) {
            final remainingWait = remainingTimeout - timeWaited;
            print('listenForYesNo: Completer completed early with null after ${timeWaited.inSeconds}s, waiting remaining ${remainingWait.inSeconds}s to give user full time');
            await Future.delayed(remainingWait);
          }
          
          // Now check for pending or partial results
          recognizedText = null;
          
          // Check pending result first (valid response during grace period)
          if (pendingResult != null && pendingResult!.isNotEmpty) {
            final testResult = _parseYesNo(pendingResult!);
            if (testResult != null) {
              print('Using pending result after full wait: $pendingResult');
              recognizedText = pendingResult;
            }
          }
          
          // Check partial result
          if (recognizedText == null && lastPartialResult != null && lastPartialResult!.isNotEmpty) {
            final testResult = _parseYesNo(lastPartialResult!);
            if (testResult != null) {
              print('Using partial result after full wait: $lastPartialResult');
              recognizedText = lastPartialResult;
            }
          }
        }
        
        final finalTimeSinceStart = DateTime.now().difference(listenStartTime);
        print('listenForYesNo: After full wait (${finalTimeSinceStart.inSeconds}s). Result: $recognizedText, Last partial: $lastPartialResult, Pending: $pendingResult, Listening: $_isListening');
      } catch (e) {
        print('listenForYesNo: Exception waiting for completer: $e');
        // Check for pending or partial results before giving up
        if (pendingResult != null && pendingResult!.isNotEmpty) {
          final testResult = _parseYesNo(pendingResult!);
          if (testResult != null) {
            recognizedText = pendingResult;
            print('Using pending result after exception: $recognizedText');
          }
        }
        if (recognizedText == null && lastPartialResult != null && lastPartialResult!.isNotEmpty) {
          recognizedText = lastPartialResult;
          print('Using partial result after exception: $recognizedText');
        }
        if (recognizedText == null) {
          if (_isListening) {
            stopListening(completeCompleter: false); // Don't complete completer, let timeout handle it
          }
          return null;
        }
      }
    } catch (e) {
      print('listenForYesNo error: $e');
      _isListening = false;
      // If we have a pending result, try to use it
      if (pendingResult != null && pendingResult!.isNotEmpty) {
        final testResult = _parseYesNo(pendingResult!);
        if (testResult != null) {
          recognizedText = pendingResult;
          print('Using pending result after error: $recognizedText');
        }
      }
      // If we have a partial result, try to use it
      if (recognizedText == null && lastPartialResult != null && lastPartialResult!.isNotEmpty) {
        recognizedText = lastPartialResult;
        print('Using partial result after error: $recognizedText');
      }
      if (recognizedText == null) {
        // If we're here, speech recognition failed to start
        // Still wait the full timeout to give user time to respond
        print('listenForYesNo: Error occurred, but waiting full timeout anyway');
        final timeoutDuration = Duration(
          seconds: (listenDuration ?? const Duration(seconds: 12)).inSeconds + 3,
        );
        await Future.delayed(timeoutDuration);
        // Now complete the completer and return null
        if (_listeningCompleter != null && !_listeningCompleter!.isCompleted) {
          _listeningCompleter!.complete(null);
        }
        return null;
      }
    }

    // Check if we got a result - but first check for any pending or partial results
    if (recognizedText == null || recognizedText!.isEmpty) {
      // Before giving up, check for pending or partial results one more time
      if (pendingResult != null && pendingResult!.isNotEmpty) {
        final testResult = _parseYesNo(pendingResult!);
        if (testResult != null) {
          recognizedText = pendingResult;
          print('listenForYesNo: Using pending result as final fallback: $recognizedText');
        }
      }
      if (recognizedText == null && lastPartialResult != null && lastPartialResult!.isNotEmpty) {
        final testResult = _parseYesNo(lastPartialResult!);
        if (testResult != null) {
          recognizedText = lastPartialResult;
          print('listenForYesNo: Using partial result as final fallback: $recognizedText');
        }
      }
      
      if (recognizedText == null || recognizedText!.isEmpty) {
        final timeSinceStart = DateTime.now().difference(listenStartTime);
        print('listenForYesNo: No recognized text after ${timeSinceStart.inSeconds}s');
        print('listenForYesNo: Final state - isListening: $_isListening, lastPartial: $lastPartialResult, pending: $pendingResult');
        return null;
      }
    }

    print('listenForYesNo: Parsing text: $recognizedText');
    // Parse yes/no response
    final result = _parseYesNo(recognizedText!);
    print('listenForYesNo: Parsed result: $result');
    return result;
  }

  /// Parse yes/no from recognized text
  /// Returns true for yes, false for no, null if unclear
  bool? _parseYesNo(String text) {
    if (text.isEmpty) return null;
    
    final normalized = text.trim().toLowerCase();
    
    // Remove common filler words and punctuation
    String cleaned = normalized
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
    
    // English yes responses - expanded with common misrecognitions
    final yesPatterns = [
      // Direct yes
      r'\byes\b', r'\byeah\b', r'\byep\b', r'\byup\b', r'\bya\b',
      // Confirmations
      r'\bcorrect\b', r'\bright\b', r'\bokay\b', r'\bok\b', r'\bokey\b',
      r'\bsure\b', r'\baffirmative\b', r'\babsolutely\b', r'\bindeed\b',
      r'\btrue\b', r'\bexactly\b', r'\bprecisely\b',
      // Phrases
      r'that\s*right', r'that\s+is\s+correct', r'that\s+is\s+right',
      r'you\s+got\s+it', r'you\s+are\s+right', r'you\s+re\s+right',
      // Common misrecognitions for "yes"
      r'\byes\s*sir\b', r'\byes\s*ma\s*am\b', r'\byes\s*please\b',
      r'\byes\s*that\b', r'\byes\s*it\b', r'\byes\s*is\b',
      // Single letter Y (common in quick responses)
      r'^\s*y\s*$', r'^\s*y\s*\.?\s*$',
    ];
    
    // English no responses - expanded with common misrecognitions
    final noPatterns = [
      // Direct no
      r'\bno\b', r'\bnope\b', r'\bnah\b', r'\bnaw\b',
      // Negations
      r'\bwrong\b', r'\bincorrect\b', r'\bfalse\b', r'\bnot\s+correct\b',
      r'\bnot\s+right\b', r'\bnegative\b', r'\bincorrectly\b',
      // Phrases
      r'that\s*wrong', r'that\s+is\s+wrong', r'that\s+is\s+not\s+correct',
      r'that\s+is\s+incorrect', r'not\s+that', r'not\s+correct',
      // Common misrecognitions for "no"
      r'\bno\s*sir\b', r'\bno\s*ma\s*am\b', r'\bno\s*way\b',
      r'\bno\s*that\b', r'\bno\s*it\b', r'\bno\s*is\b',
      // Single letter N (common in quick responses)
      r'^\s*n\s*$', r'^\s*n\s*\.?\s*$',
    ];
    
    // Turkish yes responses
    final turkishYesPatterns = [
      r'\bevet\b', r'\bdoğru\b', r'\bdogru\b', r'\btamam\b', r'\bolur\b',
      r'\bkesinlikle\b', r'\btabii\b', r'\belbette\b', r'\bdoğrudur\b',
      r'\bdogrudur\b',
    ];
    
    // Turkish no responses
    final turkishNoPatterns = [
      r'\bhayır\b', r'\bhayir\b', r'\byanlış\b', r'\byanlis\b',
      r'\bdeğil\b', r'\bdegil\b', r'\bolmaz\b', r'\byanlıştır\b',
      r'\byanlistir\b',
    ];
    
    // Score-based matching: count how many patterns match
    int yesScore = 0;
    int noScore = 0;
    
    // Check for yes patterns
    for (final pattern in yesPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(cleaned)) {
        yesScore += 2; // Higher weight for exact word matches
      }
    }
    
    for (final pattern in turkishYesPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(cleaned)) {
        yesScore += 2;
      }
    }
    
    // Check for no patterns
    for (final pattern in noPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(cleaned)) {
        noScore += 2; // Higher weight for exact word matches
      }
    }
    
    for (final pattern in turkishNoPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(cleaned)) {
        noScore += 2;
      }
    }
    
    // Also check for fuzzy matches on common misrecognitions
    // Common misrecognitions: "yes" might be heard as "this", "is", "us", etc.
    final fuzzyYesMatches = ['this', 'is', 'us', 'as', 'has', 'was', 'his'];
    for (final fuzzy in fuzzyYesMatches) {
      if (cleaned == fuzzy || cleaned.startsWith(fuzzy + ' ') || cleaned.endsWith(' ' + fuzzy)) {
        // If it's a very short response, it might be "yes" misrecognized
        if (cleaned.split(' ').length <= 2) {
          yesScore += 1;
        }
      }
    }
    
    // Common misrecognitions: "no" might be heard as "know", "now", "not", etc.
    final fuzzyNoMatches = ['know', 'now', 'not', 'note', 'node'];
    for (final fuzzy in fuzzyNoMatches) {
      if (cleaned == fuzzy || cleaned.startsWith(fuzzy + ' ') || cleaned.endsWith(' ' + fuzzy)) {
        // If it's a very short response, it might be "no" misrecognized
        if (cleaned.split(' ').length <= 2) {
          noScore += 1;
        }
      }
    }
    
    // Decision logic: return the one with higher score, but require minimum threshold
    if (yesScore > noScore && yesScore >= 1) {
      return true;
    } else if (noScore > yesScore && noScore >= 1) {
      return false;
    } else if (yesScore == noScore && yesScore > 0) {
      // If scores are equal, prefer yes (more common response)
      return true;
    }
    
    // If unclear, return null
    return null;
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

