# Adaptive video playback

Uploaded feed videos, additional post attachments, stories and Flash View videos
now get four HLS renditions, bounded by 256×144, 426×240, 640×360 and 1280×720 pixels.
The encoder preserves aspect ratio, respects portrait orientation and never
upscales. The video bitrate targets are 120, 300, 650 and 1800 kbit/s, with AAC audio
at 32, 48, 64 and 64 kbit/s respectively and two-second segments.
The smallest rendition advertises a 190 kbit/s peak including overhead. The lowest bitrate comes first in the
master playlist. Native Android/iOS video players choose a rendition according
to their bandwidth/buffer estimates; actual startup and switching depend on the
device and available connection.

Flutter uses native playback for both tap-to-play and autoplay video surfaces,
shows buffering, pauses offscreen players and releases them after four seconds.
Cache failures retry the direct adaptive stream. HLS initialization and runtime
failures then fall back to the original media URL.
A runtime fallback preserves playback position. YouTube/Facebook remain with
their existing embedded provider players.

`media_url` stays the original file for editing, download and fallback.
A separate optional `playback_url` is returned only after the entire HLS output
is ready. Existing clients remain compatible. After processing, refresh the feed
or reopen a story to obtain the new playback source. Remote direct file URLs are
not downloaded or transcoded. Browser support for HLS varies; unsupported native
playback falls back to the original file.

## Phone caching and slower connections

Android/iOS cache completed HLS playlists and segments in the app's temporary
storage, up to 100 MB with a seven-day inactivity expiry and least-recently-used
eviction. The OS may also clear temporary files. Replay uses downloaded segments;
this is not a full offline video download. Only requested segments are cached,
so browsing does not download entire videos ahead of time.

A loopback-only HTTP service lets the native player read cached segments. New
segments are streamed through immediately while being written to disk, so playback
does not wait for a whole video or whole segment to finish downloading. Concurrent
requests share an in-flight download. Raw playlists are rewritten per app session;
they retain their stable remote identity on disk. A random session token and a
strict generated-filename allowlist restrict the local server. Remote signed URLs,
external video files and provider embeds bypass this cache.

Existing Android cleartext and iOS transport settings already permit loopback
playback; no transport permissions were broadened for caching. Web builds use the
original direct network player. Cache setup is limited to two seconds, with direct
adaptive playback as fallback if the cache is unavailable. `useVideoCache: false`
on `CommunityMedia` can disable caching for a specific surface.

Streaming URLs now include `v2` so older playlists and downloaded segments stay
valid while new 144p/two-second versions are prepared. Run the backfill command
after deploying the new encoder. Original uploads and legacy streams are retained
until normal source cleanup; normal deletion removes both generations.

The first uncached play still needs sufficient network throughput: the smallest
stream is intended for roughly 200 kbit/s or faster connections. Below that rate,
pauses can still occur. Device bandwidth switching and cache playback on Android
and iOS require physical-device verification.

## Backend operation

- Install FFmpeg with `libx264` and AAC encoding on each processing server.
  `COMMUNITY_FFMPEG` can specify its absolute path. Otherwise the service uses
  `storage/app/video-tools/ffmpeg` when executable, then `ffmpeg` on PATH.
- `COMMUNITY_VIDEO_OPTIMIZE=true` enables processing by default. Set it to false
  and refresh Laravel's config cache to disable generation and streaming URLs.
- New uploads create private markers in `storage/app/video-pending`.
  `community:optimize-videos` runs from Laravel's scheduler every minute, encoding
  up to two files per invocation with a filesystem lock. No queue worker or
  additional database migration is required. The source and encoder must be on
  the same local filesystem; shared storage processing needs a designated worker.
- Ensure Laravel's scheduler runs in deployment. Alternatively, run only the
  optimization command once per minute. A dedicated cron entry for this command
  was installed for the local macOS development account on 2026-11-12; it writes
  to `storage/logs/video-optimization-worker.log`.
- On this development machine, a self-contained FFmpeg 7.1 binary from the pinned
  `imageio-ffmpeg==0.6.0` wheel is installed in local Laravel storage. The binary
  is a local tool, not a committed application asset. Install a compatible FFmpeg
  binary separately on Linux/other production hosts.
- Commands are invoked with argument arrays, accept only local upload paths,
  restrict FFmpeg network protocols and limit each rendition to ten minutes of
  processing time. Originals remain playable during processing and on failure.
- After three failed attempts the marker is renamed to `.json.failed`; inspect
  the Laravel log, correct the encoder/input issue, then rename it back to `.json`
  to retry. Interrupted encodes do not expose a partial master playlist.
- Outputs are in `storage/app/public/video-streams/v2/<source-path-hash>/`.
  Serve `.m3u8` as `application/vnd.apple.mpegurl` and `.ts` as `video/mp2t`,
  with HTTPS and correct CORS headers when media is on a separate origin.
  The storage symlink must point to this public disk. Do not put expiring
  authentication redirects in front of the static segments.
- Source deletion and orphan-media pruning also remove its derived stream.
  Originals are never replaced by the encoder. Keep the processing directories
  out of source control and include their storage usage in routine monitoring.

Queue older videos and process the first two:

```sh
php artisan community:optimize-videos --backfill --limit=2
```

Process more pending videos:

```sh
php artisan community:optimize-videos --limit=10
```

## Verification

```sh
# Laravel project
php vendor/bin/phpunit --filter 'AdaptiveVideoTest|CommunityFeatureTest'

# Flutter project
flutter test test/community_feature_test.dart test/community_video_source_test.dart test/community_video_cache_test.dart
```

The encoder integration test creates a landscape clip with audio and a silent
portrait clip, generates all four renditions, then decodes every playlist using
real FFmpeg. Other tests cover original-source preservation, source URL checks,
private pending markers, cleanup, and partial-output failure behavior. Device
bandwidth switching and playback over real mobile connections require a physical
Android/iOS check.

Implementation references: [FFmpeg HLS muxer](https://ffmpeg.org/ffmpeg-formats.html#hls)
and [Flutter HLS video format](https://pub.dev/documentation/video_player/latest/video_player/VideoFormat.html).

## Media address changes

Uploaded video and thumbnail URLs are normalized to the API request's current
server when the corresponding upload exists on that server. Stored database URLs
are preserved, external/provider/signed links retain their original identity,
and adaptive playback uses the same normalized upload origin. Flutter also
normalizes nested feed, story and Flash View media responses so older backend
responses containing a previous LAN address can play against the selected API.

On 2026-11-12, Android native playback logs identified a connection failure to
`192.168.0.118:8000` while the app used `192.168.0.120:8000`. After the fix,
all four uploaded MP4s and all four HLS masters returned HTTP 200 on the current
server using the app's existing authenticated feed session. iOS pods were updated
to include `video_player_avfoundation` and `video_thumbnail`. Playback failures
now expose an in-app retry; embedded links also retry inside their player.
The user chose to finish without physical-device playback testing.

Latest playback fix verification: 30 Flutter tests and 28 Laravel tests passed;
analysis of the modified API/media URL/player files reported no issues. Physical
phone testing and installation were skipped at the user’s request.
