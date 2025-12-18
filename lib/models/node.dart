/// Node model representing a location in the indoor map
class Node {
  final String id;
  final String name;
  final String type;
  final List<double> pos; // [x, y, z] coordinates
  final int floor;

  Node({
    required this.id,
    required this.name,
    required this.type,
    required this.pos,
    required this.floor,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      pos: List<double>.from(json['pos'] as List),
      floor: json['floor'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'pos': pos,
      'floor': floor,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

