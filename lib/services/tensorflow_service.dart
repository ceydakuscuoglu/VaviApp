import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart';
import 'package:vavi_app/models/detected_object_dm.dart';
import 'package:vavi_app/utils/tensorflow_helper.dart';
import 'package:vavi_app/values/app_constants.dart';
import 'package:vavi_app/values/typedefs.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TensorflowService {
  const TensorflowService._({required this.modelPath, required this.labelPath});

  static const ssdMobileNet = TensorflowService._(
    modelPath: AppConstants.ssdMobileNetV1,
    labelPath: AppConstants.ssdMobileNetV1LabelPath,
  );

  final String modelPath;
  final String labelPath;

  static Interpreter? _interpreter;
  static List<String>? _labels;

  Interpreter? get interpreter => _interpreter;

  List<String> get labels => _labels ?? [];

  Future<void> initialize() async {
    if (_interpreter != null) return;
    await Future.wait([
      _loadModel(),
      _loadLabels(),
    ]);
  }

  Future<void> _loadModel() async {
    final delegate = switch (defaultTargetPlatform) {
      // Use Metal Delegate for iOS Platform
      TargetPlatform.iOS => GpuDelegate(),
      // Use XNNPack Delegate for Android and Other Platforms
      _ => XNNPackDelegate(),
    };

    _interpreter = await Interpreter.fromAsset(
      modelPath,
      options: InterpreterOptions()..addDelegate(delegate),
    );

    // Output: [Tensor{..., name: normalized_input_image_tensor, type: uint8, shape: [1, 300, 300, 3], data: 270000}]
    final inputTensors = _interpreter!.getInputTensors();
    log(
      'Value: ${inputTensors.map((e) => e.toString()).toList()}',
      name: 'inputTensors',
    );

    // Output: [
    //    Tensor{..., name: TFLite_Detection_PostProcess, type: float32, shape: [1, 10, 4], data: 160},
    //    Tensor{..., name: TFLite_Detection_PostProcess:1, type: float32, shape: [1, 10], data: 40},
    //    Tensor{..., name: TFLite_Detection_PostProcess:2, type: float32, shape: [1, 10], data: 40},
    //    Tensor{..., name: TFLite_Detection_PostProcess:3, type: float32, shape: [1], data: 4}
    // ]
    final outputTensors = _interpreter!.getOutputTensors();
    log(
      'Value: ${outputTensors.map((e) => e.toString()).toList()}',
      name: 'outputTensors',
    );

    // Allocate memory for input and output tensors of model
    _interpreter!.allocateTensors();
  }

  Future<void> _loadLabels() async {
    final labelsRaw = await rootBundle.loadString(labelPath);
    _labels = labelsRaw.split('\n');
  }

  AnalyseImageCallback analyseImage(Uint8List imageData) {
    final image = decodeImage(imageData);
    if (image == null) {
      return (
        imageBytes: null,
        detectedObjects: <DetectedObjectDm>[],
      );
    }
    if (interpreter == null) {
      return (
        imageBytes: null,
        detectedObjects: <DetectedObjectDm>[],
      );
    }
    return TensorflowHelper.analyseImage(
      image,
      interpreter: interpreter!,
      label: _labels ?? [],
    );
  }
}
