class RepairBrand {
  final int id;
  final String name;
  final String slug;
  final String logo;
  final bool status;

  const RepairBrand({
    required this.id,
    required this.name,
    required this.slug,
    this.logo = '',
    this.status = true,
  });

  factory RepairBrand.fromJson(Map<String, dynamic> json) {
    return RepairBrand(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      logo: '${json['logo'] ?? ''}',
      status: json['status'] == true || json['status'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo': logo,
      'status': status ? 1 : 0,
    };
  }

  RepairBrand copyWith({
    int? id,
    String? name,
    String? slug,
    String? logo,
    bool? status,
  }) {
    return RepairBrand(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logo: logo ?? this.logo,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepairBrand &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
