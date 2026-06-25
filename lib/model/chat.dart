class Chat {
  final String id;
  final String message;
  final String sender;
  final String reciever;
  final DateTime dateTime;
  final String type;
  final String mediaUrl;
  final String mediaPath;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? durationSeconds;
  final double? latitude;
  final double? longitude;
  final String documentId;
  final bool isDeleted;
  final bool isEdited;

  Chat(
    this.id,
    this.message,
    this.sender,
    this.reciever,
    this.dateTime, {
    this.type = "text",
    this.mediaUrl = "",
    this.mediaPath = "",
    this.mediaWidth,
    this.mediaHeight,
    this.durationSeconds,
    this.latitude,
    this.longitude,
    this.documentId = "",
    this.isDeleted = false,
    this.isEdited = false,
  });

  factory Chat.fromFirestore(
    Map<String, dynamic> data, {
    required DateTime dateTime,
    String decodedMessage = "",
    String documentId = "",
  }) {
    return Chat(
      data["id"]?.toString() ?? "",
      decodedMessage,
      data["sender"]?.toString() ?? "",
      data["reciever"]?.toString() ?? "",
      dateTime,
      type: data["type"]?.toString() ?? "text",
      mediaUrl: data["media_url"]?.toString() ?? "",
      mediaPath: data["media_path"]?.toString() ?? "",
      mediaWidth: _readInt(data["media_width"]),
      mediaHeight: _readInt(data["media_height"]),
      durationSeconds: _readInt(data["duration_seconds"]),
      latitude: _readDouble(data["latitude"]),
      longitude: _readDouble(data["longitude"]),
      documentId: documentId,
      isDeleted: data["deleted"] == true,
      isEdited: data["edited"] == true,
    );
  }

  static int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _readDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}
