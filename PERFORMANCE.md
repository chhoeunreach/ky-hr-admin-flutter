# Social Feed Performance

Targets: sustained **60 FPS** scrolling on mid-range Android/iOS and **120 FPS** where the display supports it. This document records the optimization surface and how to produce before/after numbers. It does not claim measured device results until the profiling steps below are run on physical hardware.

## Flutter app

### Implemented
- Cursor-based feed pagination with request-generation cancellation and duplicate-id removal.
- `SliverList.builder` with stable post keys; only visible posts build.
- First-page offline cache (`FeedCache`, max 30 posts, 7 days) for an instant cold-start paint.
- Saved scroll offset per user, restored after the first frame has layout.
- Only the most-visible video autoplays; playback pauses while scrolling or when the tile leaves the viewport.
- Thumbnail-first video tiles; HLS segments use a bounded on-device cache.
- Image decode widths are capped to the display width and image cache is trimmed on memory pressure.
- Large feed JSON responses are decoded on a background isolate.
- Reactions update optimistically and roll back on API failure.

### Profile
Run on a physical device, in profile mode, with a release backend:

```bash
flutter run --profile
# Open DevTools > Performance, record 10 seconds of continuous scrolling.
```

Capture:
- UI frame time, raster frame time, and janky-frame percentage.
- Time to first visible post and time to first autoplaying video.
- RSS memory after 2 minutes of scrolling and after backgrounding/foregrounding.

Compare the same device, network, account, and feed contents against the baseline commit. Do not compare debug-mode builds.

## Laravel API

### Implemented / available
- Feed scope/order and interaction composite indexes in `2026_11_14_000002_add_social_feed_performance_indexes.php`.
- Eager-loaded authors, media, polls, originals, and relation counts.
- Optional short-lived per-user feed response cache (`SOCIAL_FEED_CACHE_TTL`, default disabled). Model writes bump the company cache version.
- Optional gzip for JSON responses >= 2 KB (`SOCIAL_FEED_GZIP`, `SOCIAL_FEED_GZIP_MIN_BYTES`).
- Existing queued adaptive-video processing remains opt-in through `community_video.queue`.

### Recommended production settings once Redis is available
```dotenv
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SOCIAL_FEED_CACHE_TTL=15
SOCIAL_FEED_GZIP=true
```

Keep `SOCIAL_FEED_CACHE_TTL=0` when Redis is unavailable or when strict read-after-write behavior is required.

### Profile
1. Run the feed query with `EXPLAIN`/`EXPLAIN ANALYZE` (MySQL 8) for the first page and a cursor page. Confirm the new indexes are chosen and no full table scans or temporary sorts appear for scope filters.
2. Load-test with `wrk` or `k6` using a real authenticated token and realistic feed size:
   ```bash
   k6 run --vus 20 --duration 60s feed.js
   ```
3. Compare p50/p95 latency, requests/second, DB query count, and Redis hit ratio before/after.
4. Verify compression:
   ```bash
   curl -s -H 'Accept-Encoding: gzip' -H 'Authorization: Bearer <token>' \
     -o /tmp/feed.gz -w '%{size_download}\n' \
     'https://<host>/api/social-feed?page=1'
   ```

## Verification snapshot
- Flutter: `flutter test --no-pub` -> 381 passed, 3 skipped.
- Flutter: `flutter analyze --no-pub` -> 0 errors.
- Laravel community feature suite -> 24 passed.
- Full Laravel suite has 17 pre-existing failures in unrelated chat/profile/attendance tests; the same chat failures reproduce without the feed changes.
