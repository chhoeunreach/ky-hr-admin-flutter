import 'package:cnattendance/features/community/community_media_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final current = Uri.parse('http://192.168.0.120:8000/');
  test('uploaded videos and playlists follow the current API server', () {
    expect(
        communityUploadUrl(
            'http://192.168.0.118:8000/storage/community/clip.mp4', current),
        'http://192.168.0.120:8000/storage/community/clip.mp4');
    expect(
        communityUploadUrl(
            'http://127.0.0.1:8000/storage/video-streams/v2/abc/master.m3u8',
            current),
        'http://192.168.0.120:8000/storage/video-streams/v2/abc/master.m3u8');
    expect(
        communityUploadUrl(
            'http://192.168.0.120:8001/storage/stories/clip.mov', current),
        'http://192.168.0.120:8000/storage/stories/clip.mov');
  });
  test(
      'normalizes nested shared posts and gallery thumbnails without changing input',
      () {
    final input = <String, dynamic>{
      'data': [
        {
          'original': {
            'media': [
              {
                'media_url':
                    'http://192.168.0.118:8000/storage/community/clip.mp4',
                'thumbnail_url':
                    'http://192.168.0.118:8000/storage/community/thumbnails/photo.jpg',
              }
            ]
          }
        }
      ]
    };
    final output = communityResponseMediaUrls(input, current);
    expect(output['data'][0]['original']['media'][0]['media_url'],
        contains('192.168.0.120:8000'));
    expect(output['data'][0]['original']['media'][0]['thumbnail_url'],
        contains('192.168.0.120:8000'));
    expect(input['data'][0]['original']['media'][0]['media_url'],
        contains('192.168.0.118:8000'));
  });
  test('provider, external, signed and traversal URLs retain their identity',
      () {
    for (final url in [
      'https://www.youtube.com/embed/abcdefghijk',
      'https://www.facebook.com/plugins/video.php?href=https%3A%2F%2Ffacebook.com',
      'https://cdn.example.test/storage/community/clip.mp4',
      'https://hr.kytech.info/storage/community/clip.mp4?signature=abc',
      'http://192.168.0.118:8000/storage/community/../secret.mp4',
    ]) {
      expect(communityUploadUrl(url, current), url);
    }
  });
}
