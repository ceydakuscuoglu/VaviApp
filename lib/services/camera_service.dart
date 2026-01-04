import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

/// Service for handling camera operations and frame capture
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  
  /// Initialize camera
  Future<void> initialize() async {
    try {
      // Check camera permission
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          throw Exception('Camera permission denied');
        }
      }
      
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }
      
      // Use back camera if available, otherwise use first camera
      CameraDescription? selectedCamera;
      for (final camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }
      selectedCamera ??= _cameras!.first;
      
      // Initialize camera controller
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // Medium quality for balance
        enableAudio: false,
      );
      
      await _controller!.initialize();
    } catch (e) {
      throw Exception('Failed to initialize camera: $e');
    }
  }
  
  /// Get camera controller
  CameraController? get controller => _controller;
  
  /// Check if camera is initialized
  bool get isInitialized => _controller != null && _controller!.value.isInitialized;
  
  /// Capture frames from camera preview stream at controlled intervals
  /// 
  /// [frameCount] - Number of frames to capture
  /// [intervalMs] - Interval between captures in milliseconds (default ~500ms for ~2 fps)
  /// [onProgress] - Optional callback for progress updates (current frame count)
  /// Returns a list of base64-encoded image strings
  Future<List<String>> captureFrames(
    int frameCount, {
    int intervalMs = 500,
    void Function(int currentCount)? onProgress,
  }) async {
    if (!isInitialized) {
      throw Exception('Camera not initialized');
    }
    
    if (_controller == null) {
      throw Exception('Camera controller is null');
    }
    
    final List<String> frames = [];
    final Completer<List<String>> completer = Completer<List<String>>();
    CameraImage? latestFrame;
    Timer? captureTimer;
    int capturedCount = 0;
    int failureCount = 0;
    final int maxFailures = frameCount ~/ 2;
    bool isStreamActive = true;
    bool isProcessing = false;
    
    try {
      // Start listening to camera image stream (for smooth preview)
      // We'll just store the latest frame, not process every one
      await _controller!.startImageStream((CameraImage image) {
        // Just store the latest frame - don't process it here
        // This keeps the preview smooth
        latestFrame = image;
      });
      
      // Use timer to capture frames at controlled intervals
      captureTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) async {
        // Don't process if already processing a frame or stream is inactive
        if (!isStreamActive || capturedCount >= frameCount || isProcessing) {
          if (capturedCount >= frameCount) {
            timer.cancel();
            isStreamActive = false;
            await _controller!.stopImageStream();
            if (!completer.isCompleted) {
              completer.complete(frames);
            }
          }
          return;
        }
        
        // Get the latest frame from buffer
        final frameToProcess = latestFrame;
        if (frameToProcess == null) {
          // No frame available yet, skip this interval
          return;
        }
        
        isProcessing = true;
        
        // Process frame asynchronously without blocking the timer callback
        // Use Future.microtask to process in background
        Future.microtask(() async {
          try {
            // Convert CameraImage to JPEG bytes (async, non-blocking)
            final Uint8List jpegBytes = await _convertCameraImageToJpeg(frameToProcess);
            
            if (jpegBytes.isEmpty) {
              failureCount++;
              if (failureCount > maxFailures) {
                captureTimer?.cancel();
                isStreamActive = false;
                await _controller!.stopImageStream();
                if (!completer.isCompleted) {
                  completer.completeError(Exception('Too many frame conversion failures'));
                }
                isProcessing = false;
                return;
              }
              isProcessing = false;
              return;
            }
            
            // Convert to base64
            final String base64Image = base64Encode(jpegBytes);
            frames.add(base64Image);
            capturedCount++;
            
            // Update progress callback
            onProgress?.call(capturedCount);
            
            // If we've captured enough frames, complete
            if (capturedCount >= frameCount) {
              captureTimer?.cancel();
              isStreamActive = false;
              await _controller!.stopImageStream();
              if (!completer.isCompleted) {
                completer.complete(frames);
              }
            }
            
            isProcessing = false;
          } catch (e) {
            failureCount++;
            print('Error processing frame ${capturedCount + 1}: $e');
            isProcessing = false;
            
            if (failureCount > maxFailures) {
              captureTimer?.cancel();
              isStreamActive = false;
              await _controller!.stopImageStream();
              if (!completer.isCompleted) {
                completer.completeError(Exception('Too many frame processing failures: $e'));
              }
              return;
            }
          }
        });
      });
      
      // Set a timeout to ensure we don't wait forever
      // Allow enough time for all frames (intervalMs * frameCount + buffer)
      final timeoutDuration = Duration(
        milliseconds: (intervalMs * frameCount) + 5000,
      );
      
      final result = await completer.future.timeout(
        timeoutDuration,
        onTimeout: () {
          captureTimer?.cancel();
          isStreamActive = false;
          _controller?.stopImageStream();
          if (frames.isEmpty) {
            throw Exception('Timeout: Failed to capture frames. Please try again.');
          }
          return frames; // Return what we have
        },
      );
      
      // Clean up timer if still running
      captureTimer.cancel();
      
      // Ensure we have at least some frames
      if (result.isEmpty) {
        throw Exception('Failed to capture any frames. Please try again.');
      }
      
      if (result.length < frameCount / 3) {
        throw Exception('Too few frames captured (${result.length}/$frameCount). Please try again.');
      }
      
      return result;
    } catch (e) {
      captureTimer?.cancel();
      isStreamActive = false;
      await _controller?.stopImageStream();
      rethrow;
    }
  }
  
  /// Convert CameraImage to JPEG bytes
  Future<Uint8List> _convertCameraImageToJpeg(CameraImage image) async {
    try {
      img.Image? imgImage;
      
      if (image.format.group == ImageFormatGroup.yuv420) {
        // Convert YUV420 to RGB
        imgImage = img.Image(
          width: image.width,
          height: image.height,
        );
        
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        
        // Convert YUV to RGB
        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final yIndex = y * yPlane.bytesPerRow + x;
            final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);
            
            final yValue = yPlane.bytes[yIndex];
            final uValue = uPlane.bytes[uvIndex];
            final vValue = vPlane.bytes[uvIndex];
            
            // YUV to RGB conversion
            final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
            final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
            final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();
            
            imgImage.setPixelRgba(x, y, r, g, b, 255);
          }
        }
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        // Direct BGRA format - convert to RGB
        final plane = image.planes[0];
        imgImage = img.Image(
          width: image.width,
          height: image.height,
        );
        
        // Convert BGRA to RGB
        for (int i = 0; i < plane.bytes.length; i += 4) {
          final b = plane.bytes[i];
          final g = plane.bytes[i + 1];
          final r = plane.bytes[i + 2];
          final a = plane.bytes[i + 3];
          
          final pixelIndex = i ~/ 4;
          final x = pixelIndex % image.width;
          final y = pixelIndex ~/ image.width;
          
          if (x < image.width && y < image.height) {
            imgImage.setPixelRgba(x, y, r, g, b, a);
          }
        }
      } else {
        // Unsupported format
        print('Unsupported image format: ${image.format.group}');
        return Uint8List(0);
      }
      
      // Convert to JPEG
      final jpegBytes = img.encodeJpg(imgImage, quality: 85);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('Error converting camera image: $e');
      return Uint8List(0);
    }
  }
  
  /// Dispose camera resources
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

