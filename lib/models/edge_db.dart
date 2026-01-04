/// Edge model representing a connection between nodes in the VAVI database
class EdgeDB {
  final String edgeID;
  final String? edgeType;
  final String sourceNodeID;
  final String targetNodeID;
  final double? distance;

  EdgeDB({
    required this.edgeID,
    this.edgeType,
    required this.sourceNodeID,
    required this.targetNodeID,
    this.distance,
  });

  factory EdgeDB.fromJson(Map<String, dynamic> json) {
    return EdgeDB(
      edgeID: json['edgeID'] as String,
      edgeType: json['edgeType'] as String?,
      sourceNodeID: json['sourceNodeID'] as String,
      targetNodeID: json['targetNodeID'] as String,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'edgeID': edgeID,
      'edgeType': edgeType,
      'sourceNodeID': sourceNodeID,
      'targetNodeID': targetNodeID,
      'distance': distance,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeDB &&
          runtimeType == other.runtimeType &&
          edgeID == other.edgeID;

  @override
  int get hashCode => edgeID.hashCode;

  @override
  String toString() => '$edgeID: $sourceNodeID -> $targetNodeID';
}

