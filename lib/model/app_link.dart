class AppLink {
  final int id;
  final String name;
  final String linkType;
  final String url;
  final String? image;
  final String? description;
  final int order;
  final bool status;
  final String? createdAt;

  AppLink({
    required this.id,
    required this.name,
    required this.linkType,
    required this.url,
    this.image,
    this.description,
    this.order = 0,
    this.status = true,
    this.createdAt,
  });

  factory AppLink.fromJson(Map<String, dynamic> json) {
    return AppLink(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      linkType: (json['link_type'] ?? 'other').toString().toLowerCase(),
      url: json['url']?.toString() ?? '',
      image: json['image']?.toString(),
      description: json['description']?.toString(),
      order: json['order'] is int ? json['order'] : int.tryParse(json['order']?.toString() ?? '0') ?? 0,
      status: json['status'] == true || json['status'] == 1 || json['status'] == '1',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'link_type': linkType,
      'url': url,
      'image': image,
      'description': description,
      'order': order,
      'status': status,
      'created_at': createdAt,
    };
  }
}
