part of 'cache_service.dart';

/// A class representing an item in a cache, including frequency of access and last accessed timestamp.
class _CacheItem {
  int frequency; // Frequency of access.
  DateTime lastAccessed; // Timestamp of last access.

  /// Constructs a CacheItem with the provided [frequency] and [lastAccessed] timestamp.
  _CacheItem({
    required this.frequency,
    required this.lastAccessed,
  });

  /// Constructs a CacheItem from a JSON map.
  factory _CacheItem.fromJson(Map<String, dynamic> json) {
    return _CacheItem(
      frequency: json['frequency'] as int, // Frequency from JSON.
      lastAccessed: DateTime.parse(json['lastAccessed']
          as String), // Last accessed timestamp from ISO 8601 string.
    );
  }

  /// Converts the CacheItem to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency, // Frequency of access.
      'lastAccessed': lastAccessed
          .toIso8601String(), // Last accessed timestamp in ISO 8601 format.
    };
  }
}
