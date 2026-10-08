class RepairCategory {
  final int id;
  final String name;
  final String nameKh;
  final String slug;
  final String icon;
  final int sortOrder;
  final bool status;

  const RepairCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.nameKh = '',
    this.icon = '',
    this.sortOrder = 0,
    this.status = true,
  });

  factory RepairCategory.fromJson(Map<String, dynamic> json) {
    return RepairCategory(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      nameKh: '${json['name_kh'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      icon: '${json['icon'] ?? ''}',
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      status: json['status'] == true || json['status'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_kh': nameKh,
      'slug': slug,
      'icon': icon,
      'sort_order': sortOrder,
      'status': status ? 1 : 0,
    };
  }

  RepairCategory copyWith({
    int? id,
    String? name,
    String? nameKh,
    String? slug,
    String? icon,
    int? sortOrder,
    bool? status,
  }) {
    return RepairCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKh: nameKh ?? this.nameKh,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      status: status ?? this.status,
    );
  }
}
