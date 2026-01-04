/// Node model representing a navigation node in the VAVI database
class NodeDB {
  final String nodeID;
  final String placeID;
  final double? positionX;
  final double? positionY;
  final double? positionZ;

  NodeDB({
    required this.nodeID,
    required this.placeID,
    this.positionX,
    this.positionY,
    this.positionZ,
  });

  factory NodeDB.fromJson(Map<String, dynamic> json) {
    return NodeDB(
      nodeID: json['nodeID'] as String,
      placeID: json['placeID'] as String,
      positionX: json['positionX'] != null
          ? (json['positionX'] as num).toDouble()
          : null,
      positionY: json['positionY'] != null
          ? (json['positionY'] as num).toDouble()
          : null,
      positionZ: json['positionZ'] != null
          ? (json['positionZ'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeID': nodeID,
      'placeID': placeID,
      'positionX': positionX,
      'positionY': positionY,
      'positionZ': positionZ,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeDB &&
          runtimeType == other.runtimeType &&
          nodeID == other.nodeID;

  @override
  int get hashCode => nodeID.hashCode;

  @override
  String toString() => nodeID;
}

