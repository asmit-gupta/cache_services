import 'dart:collection';

/// A simple implementation of a Least Recently Used (LRU) cache using a LinkedHashMap.
///
/// This class provides a data structure that maintains a fixed-size cache where
/// items are evicted in the order they were least recently used. It uses a
/// LinkedHashMap internally to store key-value pairs, allowing efficient
/// access, insertion, and removal operations.
///
/// The LRUCache supports the following operations:
/// - [get]: Retrieves the value associated with a given key. If the key exists
///   in the cache, its corresponding value is returned and the item's access
///   is refreshed (moved to the end of the cache). If the key does not exist,
///   null is returned.
/// - [put]: Inserts or updates a key-value pair in the cache. If the key already
///   exists, its value is updated and the item's access is refreshed. If the
///   cache exceeds its [capacity], the least recently used item is evicted
///   before inserting the new item.
/// - [clear]: Clears all entries from the cache, making it empty.
/// - [printCache]: Prints the current state of the cache for debugging purposes,
///   showing all key-value pairs in the order of their access.
///
/// Example usage:
/// ```dart
/// LRUCache<int, String> cache = LRUCache<int, String>(3);
/// cache.put(1, 'One');
/// cache.put(2, 'Two');
/// cache.put(3, 'Three');
///
/// print(cache.get(2)); // Output: 'Two'
/// cache.put(4, 'Four'); // 'One' is evicted from the cache due to capacity limit.
/// cache.printCache(); // Output: {2: 'Two', 3: 'Three', 4: 'Four'}
/// cache.clear();
/// ```
class LRUCache<K, V> {
  /// Maximum capacity of the cache.
  final int capacity;

  /// Internal cache using LinkedHashMap.
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// Constructs an LRU cache with the specified [capacity].
  LRUCache(this.capacity);

  /// Retrieves the value associated with the given [key] from the cache.
  /// Returns null if the key is not found, and moves the accessed item to the
  /// end to mark it recently used.
  V? get(K key) {
    final value = _cache[key]; // Retrieve value from cache.
    if (value != null) {
      _cache.remove(key); // Remove the key-value pair.
      _cache[key] = value; // Re-insert at the end to mark as recently used.
    }
    return value; // Return the value associated with the key.
  }

  /// Puts a key-value pair into the cache. If the key already exists, updates
  /// its value. If the cache exceeds its capacity, removes the least recently
  /// used item before insertion.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key); // Remove existing key to update its position.
    } else {
      if (_cache.length >= capacity) {
        final oldestKey =
            _cache.keys.first; // Get the oldest (least recently used) key.
        _cache.remove(oldestKey); // Remove the oldest key-value pair.
      }
    }
    _cache[key] = value; // Insert or update key-value pair.
  }

  /// Clears all entries from the cache.
  void clear() {
    _cache.clear(); // Clear all entries in the cache.
  }

  /// Prints the current state of the cache (for debugging purposes).
  void printCache() {
    print(_cache); // Print the LinkedHashMap representing the cache.
  }
}
