/// Place model representing a place/location in the VAVI system
class Place {
  final String placeID;
  final String blockID;
  final String? placeType;
  final int? floor;
  final String? placeName;

  Place({
    required this.placeID,
    required this.blockID,
    this.placeType,
    this.floor,
    this.placeName,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      placeID: json['placeID'] as String,
      blockID: json['blockID'] as String,
      placeType: json['placeType'] as String?,
      floor: json['floor'] as int?,
      placeName: json['placeName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeID': placeID,
      'blockID': blockID,
      'placeType': placeType,
      'floor': floor,
      'placeName': placeName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Place &&
          runtimeType == other.runtimeType &&
          placeID == other.placeID;

  @override
  int get hashCode => placeID.hashCode;

  @override
  String toString() => placeName ?? placeID;
}

