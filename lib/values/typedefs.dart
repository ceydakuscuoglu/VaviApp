import 'dart:typed_data';

import 'package:vavi_app/models/detected_object_dm.dart';

typedef AnalyseImageCallback = ({
  Uint8List? imageBytes,
  List<DetectedObjectDm> detectedObjects
});
