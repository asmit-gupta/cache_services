// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class CacheConfig {
  final Duration cleanupPeriod;
  final Duration maxAge;
  final int maxFileSizeBytes;
  final int maxCacheSizeBytes;
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
  
    return 
      other.cleanupPeriod == cleanupPeriod &&
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
