import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/node.dart';
import '../services/camera_service.dart';
import '../services/gemini_service.dart';
import '../services/data_loader_service.dart';

/// Screen for capturing camera frames and detecting location using Gemini API
class CameraLocationScreen extends StatefulWidget {
  final List<Node> availableNodes;

  const CameraLocationScreen({
    super.key,
    required this.availableNodes,
  });

  @override
  State<CameraLocationScreen> createState() => _CameraLocationScreenState();
}

class _CameraLocationScreenState extends State<CameraLocationScreen> {
  final CameraService _cameraService = CameraService();
  final GeminiService _geminiService = GeminiService();
  
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  int _capturedFrames = 0;
  int _totalFrames = 30;
  String? _errorMessage;
  Node? _detectedNode;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Initialize camera and start capture process
  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      await _cameraService.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });

        // Start capturing frames after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _captureAndAnalyze();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to initialize camera: ${e.toString()}';
        });
      }
    }
  }

  /// Capture frames and analyze with Gemini API
  Future<void> _captureAndAnalyze() async {
    try {
      setState(() {
        _isCapturing = true;
        _capturedFrames = 0;
        _errorMessage = null;
      });

      // Capture 30 frames with progress updates
      List<String> frames;
      try {
        frames = await _cameraService.captureFrames(
          _totalFrames,
          intervalMs: 500, // ~2 fps, adjustable
          onProgress: (currentCount) {
            // Update UI with progress
            if (mounted) {
              setState(() {
                _capturedFrames = currentCount;
              });
            }
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _isAnalyzing = false;
            final errorMsg = e.toString();
            if (errorMsg.contains('permission')) {
              _errorMessage = 'Camera permission denied. Please grant camera permission in app settings.';
            } else if (errorMsg.contains('initialized')) {
              _errorMessage = 'Camera initialization failed. Please try again.';
            } else {
              _errorMessage = 'Failed to capture frames: ${e.toString()}';
            }
          });
        }
        return;
      }
      
      if (frames.isEmpty) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _isAnalyzing = false;
            _errorMessage = 'No frames captured. Please try again.';
          });
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _capturedFrames = frames.length;
          _isCapturing = false;
          _isAnalyzing = true;
        });
      }

      // Analyze frames with Gemini API
      String? detectedText;
      try {
        detectedText = await _geminiService.analyzeFrames(frames);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            final errorMsg = e.toString().toLowerCase();
            if (errorMsg.contains('network') || errorMsg.contains('connection') || errorMsg.contains('timeout')) {
              _errorMessage = 'Network error. Please check your internet connection and try again.';
            } else if (errorMsg.contains('api key') || errorMsg.contains('auth')) {
              _errorMessage = 'API key error. Please check your API key in settings.';
            } else {
              _errorMessage = 'Failed to analyze images: ${e.toString()}';
            }
          });
        }
        return;
      }
      
      if (detectedText == null || detectedText.isEmpty) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = 'Could not detect any location text in the images. Please try again or select manually.';
          });
        }
        return;
      }

      // Extract location identifier
      final locationIdentifier = _geminiService.extractLocationIdentifier(detectedText);
      
      if (locationIdentifier == null || locationIdentifier.isEmpty) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = 'Could not extract location identifier from detected text: $detectedText';
          });
        }
        return;
      }

      // Search for matching node
      final matchingNode = DataLoaderService.findNodeByName(
        widget.availableNodes,
        locationIdentifier,
      );

      if (matchingNode == null) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = 'Could not find location matching "$locationIdentifier". Please try again or select manually.';
          });
        }
        return;
      }

      // Success - return the detected node
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _detectedNode = matchingNode;
        });

        // Wait a moment to show success, then return
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(matchingNode);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAnalyzing = false;
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('network') || errorMsg.contains('connection')) {
            _errorMessage = 'Network error. Please check your internet connection and try again.';
          } else if (errorMsg.contains('camera')) {
            _errorMessage = 'Camera error: ${e.toString()}';
          } else {
            _errorMessage = 'An error occurred: ${e.toString()}';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Find My Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && !_isCapturing && !_isAnalyzing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Go Back'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _captureAndAnalyze();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(controller),
        ),
        
        // Overlay with status
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCapturing) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Capturing frames... $_capturedFrames/$_totalFrames',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (_isAnalyzing) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Analyzing location...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (_detectedNode != null) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location found: ${_detectedNode!.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

