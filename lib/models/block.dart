/// Block model representing a block/building in the VAVI system
class Block {
  final String blockID;
  final String companyID;
  final String? blockName;

  Block({
    required this.blockID,
    required this.companyID,
    this.blockName,
  });

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      blockID: json['blockID'] as String,
      companyID: json['companyID'] as String,
      blockName: json['blockName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blockID': blockID,
      'companyID': companyID,
      'blockName': blockName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          runtimeType == other.runtimeType &&
          blockID == other.blockID;

  @override
  int get hashCode => blockID.hashCode;

  @override
  String toString() => blockName ?? blockID;
}

