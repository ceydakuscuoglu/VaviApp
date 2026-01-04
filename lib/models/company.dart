/// Company model representing a company in the VAVI system
class Company {
  final String companyID;
  final String? companyName;

  Company({
    required this.companyID,
    this.companyName,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      companyID: json['companyID'] as String,
      companyName: json['companyName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyID': companyID,
      'companyName': companyName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Company &&
          runtimeType == other.runtimeType &&
          companyID == other.companyID;

  @override
  int get hashCode => companyID.hashCode;

  @override
  String toString() => companyName ?? companyID;
}

