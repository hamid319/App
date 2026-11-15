import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for every network image. The package default keeps only 200
/// files, fewer than a few cities' place photos, so photos were downloaded
/// again and again. Pass it to each CachedNetworkImage(Provider), or a
/// precached image lands in a different cache.
final imageCacheManager = CacheManager(Config(
  'tripfamImages',
  stalePeriod: const Duration(days: 60),
  maxNrOfCacheObjects: 1000,
));
