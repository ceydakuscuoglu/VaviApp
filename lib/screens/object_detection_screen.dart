import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vavi_app/models/detected_object_dm.dart';
import 'package:vavi_app/models/screen_params.dart';
import 'package:vavi_app/services/detector.dart';
import 'package:vavi_app/services/tensorflow_service.dart';
import 'package:vavi_app/widgets/box_widget.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> with WidgetsBindingObserver {
  String? message;
  final AudioPlayer _audioPlayer = AudioPlayer();
  // --- Sound Loop State ---
  bool _isDetectingPerson = false;
  double _soundDelay = 1000.0;
  double _soundBalance = 0.0;
  bool _isSoundLoopRunning = false;

  /// List of available cameras
  late List<CameraDescription> cameras;

  int cameraIndex = 0;

  /// Controller
  CameraController? _cameraController;

  /// Object Detector is running on a background [Isolate]. This is nullable
  /// because acquiring a [Detector] is an asynchronous operation. This
  /// value is `null` until the detector is initialized.
  Detector? _detector;

  StreamSubscription? _objectDetectorStream;

  /// Results to draw bounding boxes
  List<DetectedObjectDm>? detectedObjectList;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _startSoundLoop();
  }

  Future<void> _startSoundLoop() async {
    if (_isSoundLoopRunning) return;
    _isSoundLoopRunning = true;

    while (mounted) {
      if (_isDetectingPerson) {
        try {
          // Play sound
          await _audioPlayer.setBalance(_soundBalance);
          await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
        } catch (e) {
          log('Error playing sound: $e');
        }

        // Wait dynamic delay based on proximity
        int delay = _soundDelay.toInt();
        // Ensure delay is reasonable (e.g., minimum 50ms to prevent UI freeze or audio issues)
        if (delay < 50) delay = 50; 
        
        await Future.delayed(Duration(milliseconds: delay));
      } else {
        // Idle check interval
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    _isSoundLoopRunning = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.stopImageStream();
      _objectDetectorStream?.cancel();
      _detector?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('Live Object Detection')),
      body: controller == null || !controller.value.isInitialized
          ? Center(child: Text(message ?? 'Initializing...'))
          : Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1 / controller.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        // Bounding boxes
                        ...?detectedObjectList?.map(
                          (detectedObject) => Positioned.fromRect(
                            rect: detectedObject.renderLocation,
                            child: BoxWidget.fromDetectedObject(detectedObject),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _objectDetectorStream?.cancel();
    _detector?.stop();
    super.dispose();
  }

  Future<void> _init() async {
    await _initializeCamera();
    await TensorflowService.ssdMobileNet.initialize();
    await _initializeDetector();

    /// Listen each frame from calling the image stream
    if (_cameraController != null && _cameraController!.value.isInitialized) {
         await _cameraController?.startImageStream(onLatestImageAvailable);
    
        /// previewSize is size of each image frame captured by controller
        final size = _cameraController?.value.previewSize;
        if (size != null) {
          ScreenParams.previewSize = size;
          ScreenParams.screenPreviewSize = size; // Initialize screenPreviewSize too
        }
    }
    
    // Update screen size
    if (mounted) {
        ScreenParams.screenSize = MediaQuery.of(context).size;
        setState(() {});
    }
  }

  /// Initializes the camera by setting [_cameraController]
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        message = 'No Camera Available';
        if (mounted) setState(() {});
        log('No Camera Available');
        return;
      }
      // cameras[0] for back-camera
      cameraIndex = 0;
      final camera = cameras[cameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController?.initialize();
    } catch (e) {
      message = 'Failed to initialize camera: $e';
      if (mounted) setState(() {});
    }
  }

  Future<void> _initializeDetector() async {
    final detector = await Detector.start();

    if (mounted) {
        setState(() {
          _detector = detector;
          _objectDetectorStream = detector.resultsStream.listen((detectedObjects) {
            if (mounted) {
              // 1. FILTER ONLY PERSONS
              final persons = detectedObjects
                  .where((object) => object.label == 'person')
                  .toList();
              
              setState(() => detectedObjectList = persons);
    
              // 2. CALCULATE LOGIC FOR SOUND LOOP
              final detectedPerson = persons.firstOrNull; // Use the first (highest confidence) person
    
              if (detectedPerson != null) {
                final objectArea = detectedPerson.renderLocation.width *
                    detectedPerson.renderLocation.height;
    
                const minAreaThreshold = 10000.0; // Lowered threshold for responsiveness
    
                if (objectArea > minAreaThreshold) {
                   _isDetectingPerson = true;

                  // --- Direction / Balance Calculation ---
                  double screenWidth = ScreenParams.screenSize.width;
                  if (screenWidth == 0) screenWidth = 300; 
    
                  final objectCenterX = detectedPerson.renderLocation.center.dx;
                  final normalizedPosition = objectCenterX / screenWidth;
                  // Map 0.0-1.0 to -1.0-1.0
                  final balance = (normalizedPosition * 2) - 1;
                  _soundBalance = balance.clamp(-1.0, 1.0);
    
                  // --- Dynamic Delay Calculation (Metal Detector Effect) ---
                  const maxArea = 200000.0; 
                  const minArea = minAreaThreshold;
                  // Fast beeps (small delay) when close (large area)
                  // Slow beeps (large delay) when far (small area)
                  const slowBeepDelay = 800.0;
                  const fastBeepDelay = 100.0;
                  
                  final clampedArea = objectArea.clamp(minArea, maxArea);
                  
                  // Linear calculation:
                  // area = min -> delay = slow
                  // area = max -> delay = fast
                  final ratio = (clampedArea - minArea) / (maxArea - minArea);
                  
                  _soundDelay = slowBeepDelay - (ratio * (slowBeepDelay - fastBeepDelay));
                  
                  // log('Detected Person! Area: ${objectArea.toInt()}, Delay: ${_soundDelay.toInt()}ms');
                } else {
                  _isDetectingPerson = false;
                }
              } else {
                _isDetectingPerson = false;
              }
            }
          });
        });
    }
  }

  /// Callback to receive each frame [CameraImage] perform inference on it
  void onLatestImageAvailable(CameraImage cameraImage) {
    _detector?.processFrame(cameraImage);
  }
}
