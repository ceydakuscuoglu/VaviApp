import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Internal class for queue items
class _TtsQueueItem {
  final String text;
  final String? language;
  final bool waitForCompletion;
  final Completer<void> completer;

  _TtsQueueItem({
    required this.text,
    this.language,
    required this.waitForCompletion,
    required this.completer,
  });
}

/// Service for handling text-to-speech functionality
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Completer<void>? _currentSpeechCompleter;
  final List<_TtsQueueItem> _queue = [];
  bool _isProcessingQueue = false;

  /// Initialize TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Set default language to English
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5); // Normal speech rate
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      // Set error handler
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Process the TTS queue
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _queue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    while (_queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      
      try {
        // Stop any ongoing speech first
        if (_isSpeaking) {
          await _flutterTts.stop();
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Set language if provided
        if (item.language != null) {
          await _flutterTts.setLanguage(item.language!);
        }

        _isSpeaking = true;
        _currentSpeechCompleter = item.completer;
        
        await _flutterTts.speak(item.text);
        
        if (item.waitForCompletion) {
          // Wait for completion
          await _flutterTts.awaitSpeakCompletion(true);
          // Add a small delay to ensure TTS is fully stopped
          await Future.delayed(const Duration(milliseconds: 300));
        }
        
        _isSpeaking = false;
        _currentSpeechCompleter?.complete();
        _currentSpeechCompleter = null;
      } catch (e) {
        _isSpeaking = false;
        _currentSpeechCompleter?.completeError(e);
        _currentSpeechCompleter = null;
        print('TTS Error: $e');
      }
    }
    
    _isProcessingQueue = false;
  }

  /// Speak text
  /// Returns a Future that completes when speaking is done
  Future<void> speak(String text, {String? language}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) return;

    final completer = Completer<void>();
    _queue.add(_TtsQueueItem(
      text: text,
      language: language,
      waitForCompletion: false,
      completer: completer,
    ));
    
    _processQueue();
    return completer.future;
  }

  /// Speak text and wait for completion
  Future<void> speakAndWait(String text, {String? language}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) return;

    final completer = Completer<void>();
    _queue.add(_TtsQueueItem(
      text: text,
      language: language,
      waitForCompletion: true,
      completer: completer,
    ));
    
    _processQueue();
    return completer.future;
  }

  /// Stop speaking
  Future<void> stop() async {
    // Clear the queue
    for (final item in _queue) {
      item.completer.complete();
    }
    _queue.clear();
    
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      _currentSpeechCompleter?.complete();
      _currentSpeechCompleter = null;
    }
  }

  /// Set speech rate (0.0 to 1.0, where 0.0 is slowest and 1.0 is fastest)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Dispose resources
  void dispose() {
    if (_isSpeaking) {
      _flutterTts.stop();
    }
    _isSpeaking = false;
    _isInitialized = false;
  }
}

