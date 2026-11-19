import 'package:cnattendance/utils/chat/chat_message_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text messages are shown trimmed', () {
    expect(chatMessagePreview('text', '  Hello  '), 'Hello');
  });

  test('media messages get a readable placeholder', () {
    expect(chatMessagePreview('image', ''), 'Sent a photo');
    expect(chatMessagePreview('voice', ''), 'Sent a voice message');
    expect(chatMessagePreview('file', ''), 'Sent a file');
    expect(chatMessagePreview('location', ''), 'Shared a location');
  });

  test('a caption wins over the placeholder and unknown types stay empty', () {
    expect(chatMessagePreview('image', 'caption'), 'caption');
    expect(chatMessagePreview('sticker', ''), '');
  });
}
