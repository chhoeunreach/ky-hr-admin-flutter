String chatMessagePreview(String type, String decoded) {
  final text = decoded.trim();
  if (text.isNotEmpty) {
    return text;
  }

  switch (type) {
    case 'image':
      return 'Sent a photo';
    case 'voice':
      return 'Sent a voice message';
    case 'file':
      return 'Sent a file';
    case 'location':
      return 'Shared a location';
    default:
      return '';
  }
}
