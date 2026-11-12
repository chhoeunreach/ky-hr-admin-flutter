class Feature {
  Feature({
    required this.name,
    required this.key,
    required this.status,
  });

  factory Feature.fromJson(dynamic json) {
    return Feature(
        name: json['name'].toString(),
        key: json['key'].toString(),
        status: ['1', 'true'].contains(json['status'].toString().toLowerCase())
            ? '1'
            : '0');
  }

  String name;
  String key;
  String status;
}
