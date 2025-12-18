/// Edge model representing a connection between two nodes
class Edge {
  final String source;
  final String target;
  final double distance;
  final String type;

  Edge({
    required this.source,
    required this.target,
    required this.distance,
    required this.type,
  });

  factory Edge.fromJson(Map<String, dynamic> json) {
    return Edge(
      source: json['source'] as String,
      target: json['target'] as String,
      distance: (json['distance'] as num).toDouble(),
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'target': target,
      'distance': distance,
      'type': type,
    };
  }
  //dmsandf
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Edge &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          target == other.target;

  @override
  int get hashCode => source.hashCode ^ target.hashCode;
}

