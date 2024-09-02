// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

/// A configuration class for managing cache settings.
///
/// This class encapsulates various parameters that control the behavior of a caching system,
/// including cleanup frequency, maximum age of cached items, size limits, and retry attempts.
///
/// Properties:
/// - [cleanupPeriod]: The duration between cache cleanup operations.
/// - [maxAge]: The maximum duration for which a cached item is considered valid.
/// - [maxFileSizeBytes]: The maximum size in bytes allowed for a single cached file.
/// - [maxCacheSizeBytes]: The maximum total size in bytes allowed for the entire cache.
/// - [maxRetries]: The maximum number of retry attempts for cache operations.
///
/// This class provides methods for:
/// - Creating a new instance with [CacheConfig()]
/// - Creating a copy with some properties changed using [copyWith()]
/// - Converting the configuration to a map with [toMap()]
/// - Serializing to JSON with [toJson()]
/// - Custom string representation with [toString()]
/// - Equality comparison with [==]
/// - Consistent [hashCode] generation
///
/// Usage example:
/// ```dart
/// final config = CacheConfig(
///   cleanupPeriod: Duration(hours: 1),
///   maxAge: Duration(days: 7),
///   maxFileSizeBytes: 1024 * 1024 * 10, // 10 MB
///   maxCacheSizeBytes: 1024 * 1024 * 100, // 100 MB
///   maxRetries: 3,
/// );
///
/// // Create a copy with modified maxAge
/// final newConfig = config.copyWith(maxAge: Duration(days: 14));
///
/// // Convert to JSON
/// final jsonString = config.toJson();
/// ```
///
/// Note: This class uses `json.encode()` from `dart:convert` for JSON serialization.
/// Make sure to import 'dart:convert' when using the [toJson()] method.
class CacheConfig {
  /// The duration between cache cleanup operations.
  ///
  /// This property determines how frequently the cache system should perform
  /// cleanup operations to remove expired or unnecessary items.
  final Duration cleanupPeriod;

  /// The maximum duration for which a cached item is considered valid.
  ///
  /// Any item in the cache older than this duration will be considered stale
  /// and may be removed during cleanup operations.
  final Duration maxAge;

  /// The maximum size in bytes allowed for a single cached file.
  ///
  /// This limit prevents individual cache entries from becoming too large and
  /// consuming excessive storage space.
  final int maxFileSizeBytes;

  /// The maximum total size in bytes allowed for the entire cache.
  ///
  /// This property sets an upper bound on the total storage space that can be
  /// used by all cached items combined.
  final int maxCacheSizeBytes;

  /// The maximum number of retry attempts for cache operations.
  ///
  /// This value determines how many times a cache operation (e.g., write, read)
  /// should be retried in case of failure before giving up.
  final int maxRetries;
  CacheConfig({
    required this.cleanupPeriod,
    required this.maxAge,
    required this.maxFileSizeBytes,
    required this.maxCacheSizeBytes,
    required this.maxRetries,
  });

  CacheConfig copyWith({
    Duration? cleanupPeriod,
    Duration? maxAge,
    int? maxFileSizeBytes,
    int? maxCacheSizeBytes,
    int? maxRetries,
  }) {
    return CacheConfig(
      cleanupPeriod: cleanupPeriod ?? this.cleanupPeriod,
      maxAge: maxAge ?? this.maxAge,
      maxFileSizeBytes: maxFileSizeBytes ?? this.maxFileSizeBytes,
      maxCacheSizeBytes: maxCacheSizeBytes ?? this.maxCacheSizeBytes,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cleanupPeriod': cleanupPeriod.inMilliseconds,
      'maxAge': maxAge.inMilliseconds,
      'maxFileSizeBytes': maxFileSizeBytes,
      'maxCacheSizeBytes': maxCacheSizeBytes,
      'maxRetries': maxRetries,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'CacheConfig(cleanupPeriod: $cleanupPeriod, maxAge: $maxAge, maxFileSizeBytes: $maxFileSizeBytes, maxCacheSizeBytes: $maxCacheSizeBytes, maxRetries: $maxRetries)';
  }

  @override
  bool operator ==(covariant CacheConfig other) {
    if (identical(this, other)) return true;

    return other.cleanupPeriod == cleanupPeriod &&
        other.maxAge == maxAge &&
        other.maxFileSizeBytes == maxFileSizeBytes &&
        other.maxCacheSizeBytes == maxCacheSizeBytes &&
        other.maxRetries == maxRetries;
  }

  @override
  int get hashCode {
    return cleanupPeriod.hashCode ^
        maxAge.hashCode ^
        maxFileSizeBytes.hashCode ^
        maxCacheSizeBytes.hashCode ^
        maxRetries.hashCode;
  }
}
