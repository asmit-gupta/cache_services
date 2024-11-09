import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:cache_service/src/services/cache_services/cache_config.dart';
import 'package:cache_service/src/services/cache_services/data_structure/lru_cache.dart';
import 'package:cache_service/src/services/cache_services/data_structure/queue.dart';
import 'package:cache_service/src/services/encryption_services/encryption_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logger/logger.dart';
part 'logger/log.dart';
part 'box_names.dart';
part 'cache_item.dart';

// Cache Service to maintain application-wide caching of data, including network images, pdfs and in-memory cache
/// with capabilities for cleanup and space management.
///
/// This service utilizes Hive for local storage and includes an LRU cache for efficient
/// management of cached items. It supports caching images & pdfs fetched from network URLs,
/// with automatic cleanup based on configurable criteria like cache size limits and
/// item age. The service handles caching operations asynchronously and includes
/// error handling and retry mechanisms for fetching network resources. It is a singleton class.
///
/// Usage:
/// - Initialize the service using `initialize()` before any caching operations.
/// - Cache images from network URLs using `cacheImage(imageUrl)`.
/// - Retrieve cached images synchronously using `getCachedImage(imageUrl)`.
/// - Optionally clear the entire cache using `clearCache()`.
///
/// Example:
/// ```dart
/// final cacheService = CacheService();
/// await cacheService.initialize();
/// ```
class CacheService {
  // Singleton instance of CacheService
  static final CacheService _instance = CacheService._internal();
  // Factory constructor returning the singleton instance
  factory CacheService() => _instance;
  // Internal constructor for singleton pattern
  CacheService._internal();
  late final CacheConfig _cacheConfig;
  late final CustomLogger logger;
  late Box<String> _freqBox; // Hive box for storing frequency data
  late Box<Uint8List> _cacheBox; // Hive box for storing cached data
  late Box<dynamic> _miscBox; // Hive box for storing miscellaneous data
  // static const Duration _cacheConfig.cleaupPeriod =
  //     Duration(days: 15); // Duration for cache cleanup period
  // static const Duration _cacheConfig.maxAge =
  //     Duration(days: 30); // Maximum age for cache it ems
  // static const int _cacheConfig.maxFileSizeBytes =
  //     150 * 1024 * 1024; // Maximum size for individual cache files (150 MB)
  // static const int _cacheConfig.maxCacheSizeBytes =
  //     500 * 1024 * 1024; // Maximum size for the entire cache (500 MB)
  static DateTime? _lastCleanupDate; // Last date when cache cleanup occurred
  static DateTime? _lastMaxAgeCheck; // Last date when max age check occurred
  // static const int _cacheConfig.maxRetries =
  //     3; // Maximum number of retries for failed operations

  static const Duration _retryDelay = Duration(
      milliseconds: 500); // Delay between retries for failed operations

  final LRUCache<String, Uint8List> _networkCache = LRUCache<String, Uint8List>(
      100); // LRU cache for network responses with a maximum of 100 entries
  final HashSet<String> _pendingRequests =
      HashSet<String>(); // Set of currently pending network requests

  /// Initializes the CacheService by opening necessary boxes, retrieving the last cleanup date,
  /// setting the last max age check to the current time, and scheduling the next cleanup.
  ///
  /// Workflow:
  /// 1. Log the start of the initialization process.
  /// 2. Open the required boxes.
  /// 3. Retrieve the last cleanup date.
  /// 4. Set the last max age check to the current time.
  /// 5. Schedule the next cleanup.
  /// 6. Log the completion of the initialization process.
  ///
  /// Example usage:
  /// ```dart
  /// await initialize();
  /// ```
  Future<void> initialize({
    CacheConfig? cacheConfig,
    bool showLogs = true,
  }) async {
    _cacheConfig = cacheConfig ??
        CacheConfig(
            cleanupPeriod: Duration(days: 15),
            maxAge: Duration(days: 30),
            maxFileSizeBytes: 150 * 1024 * 1024,
            maxCacheSizeBytes: 500 * 1024 * 1024,
            maxRetries: 3);
    logger = CustomLogger(showLogs: !showLogs);
    await Hive.initFlutter();
    logger.d("CacheService initialization started");
    logger.d("Opening boxes");
    await _openBoxes();
    logger.d("Boxes opened");
    _lastCleanupDate = await _getLastCleanupDate();
    logger.d("Last cleanup date retrieved");
    _lastMaxAgeCheck = DateTime.now();
    logger.d("Scheduling next cleanup");
    _scheduleNextCleanup();
    logger.d("Next cleanup scheduled");
    logger.d("CacheService initialization completed");
  }

  /// Opens Hive boxes for frequency data, cached images, and miscellaneous data,
  /// retrying up to [_cacheConfig.maxRetries] times with a delay of [_retryDelay] between retries
  /// on encountering an error.
  ///
  /// Throws an error if maximum retry attempts are reached without successful box opening.
  Future<void> _openBoxes() async {
    int retryCount = 0;

    while (retryCount < _cacheConfig.maxRetries) {
      try {
        if (await Hive.boxExists(_BoxNames.frequencyBox)) {
          _freqBox = Hive.isBoxOpen(_BoxNames.frequencyBox)
              ? Hive.box<String>(_BoxNames.frequencyBox)
              : await Hive.openBox<String>(_BoxNames.frequencyBox);
        } else {
          _freqBox = await Hive.openBox<String>(_BoxNames.frequencyBox);
        }

        if (await Hive.boxExists(_BoxNames.cacheBox)) {
          _cacheBox = Hive.isBoxOpen(_BoxNames.cacheBox)
              ? Hive.box<Uint8List>(_BoxNames.cacheBox)
              : await Hive.openBox<Uint8List>(_BoxNames.cacheBox);
        } else {
          _cacheBox = await Hive.openBox<Uint8List>(_BoxNames.cacheBox);
        }

        if (await Hive.boxExists(_BoxNames.miscBox)) {
          _miscBox = Hive.isBoxOpen(_BoxNames.miscBox)
              ? Hive.box<dynamic>(_BoxNames.miscBox)
              : await Hive.openBox<dynamic>(_BoxNames.miscBox);
        } else {
          _miscBox = await Hive.openBox<dynamic>(_BoxNames.miscBox);
        }

        // If all boxes are successfully opened, exit the loop
        break;
      } catch (e, stackTrace) {
        logger.e('Failed to open Hive boxes: $e, $stackTrace');

        retryCount++;
        if (retryCount >= _cacheConfig.maxRetries) {
          logger.e('Max retries reached. Could not open Hive boxes.');
          break;
        }

        // Waiting for a specified delay before retrying
        await Future.delayed(_retryDelay);
      }
    }
  }

  /// Retrieves the last cleanup date from the miscellaneous data Hive box.
  ///
  /// Returns [DateTime] if the last cleanup date is found and successfully parsed,
  /// otherwise returns `null`. Logs debug and error messages for method entry,
  /// successful date parsing, absence of cleanup date, and encountered errors.
  Future<DateTime?> _getLastCleanupDate() async {
    logger.d("Entering _getLastCleanupDate");
    try {
      if (!_miscBox.isOpen) {
        await _openMiscBox();
      }

      final lastCleanupString = _miscBox.get('lastCleanupDate');
      logger.i("Retrieved lastCleanupString: $lastCleanupString");

      if (lastCleanupString != null) {
        final parsedDate = DateTime.parse(lastCleanupString);
        logger.d("Date parsed successfully: $parsedDate");
        return parsedDate;
      } else {
        logger.i("No lastCleanupDate found in _miscBox");
        return null;
      }
    } catch (e, stackTrace) {
      logger.e("Error in _getLastCleanupDate: $e");
      logger.e("Stack trace: $stackTrace");
      return null;
    }
  }

  ///to open the misc box of the hive, which stores misc data of the cache service
  Future<void> _openMiscBox() async {
    if (await Hive.boxExists(_BoxNames.miscBox)) {
      _miscBox = Hive.isBoxOpen(_BoxNames.miscBox)
          ? Hive.box<dynamic>(_BoxNames.miscBox)
          : await Hive.openBox<dynamic>(_BoxNames.miscBox);
    } else {
      _miscBox = await Hive.openBox<dynamic>(_BoxNames.miscBox);
    }
  }

  /// Caches an image from the network if it is not already cached.
  ///
  /// Uses [imageUrl] to generate a hashed key for caching. Fetches image bytes
  /// from the network, checks if the image size is within [_cacheConfig.maxFileSizeBytes],
  /// and ensures sufficient space in the cache before caching the image.
  ///
  /// Logs successful caching, file size issues, or network fetch failures.
  ///
  /// Throws an error if caching fails due to any reason.
  Future<void> cacheImage(String imageUrl) async {
    final hashedImageUrl = EncryptionService.hashString(imageUrl);

    try {
      if (!_cacheBox.containsKey(hashedImageUrl)) {
        final fileBytes = await _fetchImageBytesFromNetwork(imageUrl);

        if (fileBytes != null &&
            fileBytes.length <= _cacheConfig.maxFileSizeBytes) {
          if (await _hasSpaceInCache(fileBytes.length)) {
            await _cacheImage(hashedImageUrl, fileBytes);
            logger.i('Image cached successfully: $imageUrl');
          } else {
            await _makeSpaceForNewItem(fileBytes.length);
            await _cacheImage(hashedImageUrl, fileBytes);
            logger.i('Image cached after cleanup: $imageUrl');
          }
        } else {
          logger.i('File too large or failed to fetch: $imageUrl');
        }
      }
    } catch (e, stackTrace) {
      logger.e(
          'Failed to cache image: $imageUrl, error: $e, stack trace: $stackTrace');
    }
  }

  /// Checks if there is enough space in the cache to store a file of the given size.
  ///
  /// This method calculates the current size of the cache and determines if adding a file of the specified size
  /// would exceed the maximum allowed cache size.
  Future<bool> _hasSpaceInCache(int fileSize) async {
    final currentCacheSize = await _getCacheSizeInBytes();
    return currentCacheSize + fileSize <= _cacheConfig.maxCacheSizeBytes;
  }

  /// Caches an image by storing it in the cache box and updating its access frequency.
  ///
  /// This method performs the following steps:
  /// 1. Stores the image bytes in the cache box with the given hashed image URL as the key.
  /// 2. Increments the access frequency of the image.
  /// 3. Updates the frequency box with a new `_CacheItem` containing the initial frequency and the current timestamp.
  ///
  /// The method ensures that the image is properly cached and its metadata is updated for efficient cache management.
  ///
  /// Example usage:
  /// ```dart
  /// Uint8List imageBytes = ... // Your image bytes
  /// String hashedUrl = ... // Your hashed image URL
  /// await _cacheImage(hashedUrl, imageBytes);
  /// ```
  ///
  /// Parameters:
  /// - `hashedImageUrl` (`String`): The hashed URL of the image to be cached.
  /// - `fileBytes` (`Uint8List`): The bytes of the image to be cached.
  ///
  /// Returns:
  /// - A `Future<void>` that completes when the image has been cached and its metadata updated.
  ///
  /// Throws:
  /// - Any exceptions that might occur during the caching process.
  Future<void> _cacheImage(String hashedImageUrl, Uint8List fileBytes) async {
    await _cacheBox.put(hashedImageUrl, fileBytes);
    await _increaseFrequency(hashedImageUrl);
    await _freqBox.put(
        hashedImageUrl,
        jsonEncode(
            _CacheItem(frequency: 1, lastAccessed: DateTime.now()).toJson()));
  }

  /// Retrieves an image from the cache or fetches it from the network if not cached.
  ///
  /// This method performs the following steps:
  /// 1. If the provided `imageUrl` is null, it returns a placeholder image.
  /// 2. Hashes the image URL to create a cache key.
  /// 3. Checks if the image is present in the cache:
  ///    - If present, logs the event, increases the access frequency, and returns the image from the cache.
  ///    - If not present, fetches the image bytes from the network.
  /// 4. If the image is fetched from the network, it caches the image and returns it.
  /// 5. If any error occurs during the process, it logs the error and returns a placeholder image.
  ///
  /// Example usage:
  /// ```dart
  /// String? imageUrl = ... // URL of the image to be retrieved
  /// ImageProvider imageProvider = await getCachedImage(imageUrl);
  /// ```
  ///
  /// Parameters:
  /// - `imageUrl` (`String?`): The URL of the image to be retrieved. If null, a placeholder image is returned.
  ///
  /// Returns:
  /// - A `Future<ImageProvider>` that resolves to the image provider for the requested image, or a placeholder image
  ///   if the URL is null or an error occurs.
  ///
  /// Throws:
  /// - Any exceptions that might occur during the image retrieval process.
  Future<ImageProvider> getCachedImage(String? imageUrl) async {
    Stopwatch stopwatch = Stopwatch()..start();
    if (imageUrl == null) {
      return _getPlaceholderImage();
    }

    final hashedImageUrl = EncryptionService.hashString(imageUrl);

    try {
      if (_cacheBox.containsKey(hashedImageUrl)) {
        stopwatch.stop();
        logger.i(
            'Image loaded from cache: $hashedImageUrl in ${stopwatch.elapsed.inMilliseconds} milliseconds');
        await _increaseFrequency(hashedImageUrl);

        return MemoryImage(_cacheBox.get(hashedImageUrl)!);
      } else {
        final imageBytes = await _fetchImageBytesFromNetwork(imageUrl);
        if (imageBytes != null) {
          await cacheImage(imageUrl);
          stopwatch.stop();
          logger.i(
              'Image cached and loaded: $imageUrl in ${stopwatch.elapsed.inMilliseconds} milliseconds');
          return MemoryImage(imageBytes);
        } else {
          stopwatch.stop();
          logger.i(
              'Placeholder loaded: $imageUrl in ${stopwatch.elapsed.inMilliseconds} milliseconds');
          return _getPlaceholderImage();
        }
      }
    } catch (e, stackTrace) {
      logger.e('Error loading image: $e, $stackTrace');
      return _getPlaceholderImage();
    }
  }

  ImageProvider _getPlaceholderImage() {
    return const AssetImage('lib/src/assets/placeholder_image.png');
  }

  /// Fetches image bytes from a network URL, with caching and retry logic.
  ///
  /// This method first checks if the image is already cached in the LRU cache.
  /// If not, it attempts to fetch the image from the network, with retries
  /// and error handling. The fetched image bytes are cached for future use.
  /// The method also ensures that multiple concurrent requests for the same
  /// URL are handled efficiently.
  ///
  /// Parameters:
  /// - `imageUrl`: The URL of the image to fetch.
  ///
  /// Returns:
  /// - `Future<Uint8List?>`: A `Future` that resolves to the image bytes if
  ///   the image is successfully fetched, or `null` if the fetch fails.
  ///
  /// Workflow:
  /// 1. Check if the image is already in the LRU cache. If so, return the cached bytes.
  /// 2. Wait for any pending requests with the same URL to complete.
  /// 3. Add the URL to the pending requests set to avoid duplicate requests.
  /// 4. Initialize `retryCount` to 0 and `imageBytes` to null.
  /// 5. Enter a retry loop that runs until the image is fetched or the
  ///    maximum number of retries is reached:
  ///    - Attempt to fetch the image using the Dio library.
  ///    - If the response status code is 200, check the Content-Type header to
  ///      ensure it is an image.
  ///    - If the Content-Type is valid, convert the response data to `Uint8List`
  ///      and cache it in the LRU cache.
  ///    - If the fetch fails, log the error and increment the retry count.
  ///    - If the retry count is less than the maximum, wait for a specified
  ///      delay before retrying.
  /// 6. Remove the URL from the pending requests set before returning.
  ///
  /// Example usage:
  /// ```dart
  /// Uint8List? imageData = await _fetchImageBytesFromNetwork('https://example.com/image.png');
  /// if (imageData != null) {
  ///   // Use the image data
  /// }
  /// ```
  ///
  Future<Uint8List?> _fetchImageBytesFromNetwork(String imageUrl) async {
    // Check if the image is in the LRU cache
    final cachedBytes = _networkCache.get(imageUrl);
    if (cachedBytes != null) {
      return cachedBytes;
    }

    // Wait for any pending requests with the same URL to complete
    await _waitForPendingRequest(imageUrl);

    final updatedCachedBytes = _networkCache.get(imageUrl);
    if (updatedCachedBytes != null) {
      return updatedCachedBytes;
    }

    // Add the URL to the pending requests set
    _pendingRequests.add(imageUrl);

    int retryCount = 0;
    Uint8List? imageBytes;

    try {
      final dio = Dio();
      while (retryCount < _cacheConfig.maxRetries) {
        try {
          final response = await dio.get(imageUrl,
              options: Options(responseType: ResponseType.bytes));
          if (response.statusCode == 200) {
            final contentType = response.headers['content-type'];
            if (contentType == null || contentType.isEmpty) {
              throw Exception('No Content-Type header found in response');
            }

            final mimeType = contentType.first.split(';').first;
            if (!mimeType.startsWith('image/')) {
              throw Exception('Unsupported file format: $mimeType');
            }

            imageBytes = Uint8List.fromList(response.data);
            // Add the fetched image to the LRU cache
            _networkCache.put(imageUrl, imageBytes);
            break;
          } else {
            logger.i('Failed to load image: ${response.statusCode}');
            return null; // Return null to indicate failure
          }
        } catch (e) {
          logger.i('Error fetching image: $e');
        }

        retryCount++;
        if (retryCount < _cacheConfig.maxRetries) {
          await Future.delayed(_retryDelay);
        }
      }

      return imageBytes;
    } finally {
      _pendingRequests.remove(imageUrl);
    }
  }

  Future<void> _waitForPendingRequest(String imageUrl) async {
    while (_pendingRequests.contains(imageUrl)) {
      await Future.delayed(_retryDelay);
    }
  }

  /// Increases the frequency count of a cache item and updates its last accessed time.
  ///
  /// This method retrieves a cache item associated with a given key from the frequency box.
  /// If the item exists, it increments its frequency count and updates its last accessed time.
  /// If the item does not exist, it creates a new `_CacheItem` with a frequency of 1 and the current time.
  /// The updated item is then stored back in the frequency box.
  ///
  /// Parameters:
  /// - `key`: The key associated with the cache item whose frequency is to be increased.
  ///
  /// Returns:
  /// - `Future<void>`: A `Future` that completes when the frequency update is done.
  ///
  /// Workflow:
  /// 1. Check if the frequency box contains an item for the given key.
  /// 2. If the item exists, decode its JSON representation to a `_CacheItem` object.
  ///    If the item does not exist, create a new `_CacheItem` with a frequency of 0 and the current time.
  /// 3. Increment the frequency count of the `_CacheItem` object.
  /// 4. Update the last accessed time of the `_CacheItem` object to the current time.
  /// 5. Encode the updated `_CacheItem` object back to a JSON string and store it in the frequency box.
  /// 6. Log the updated frequency for the given key.
  ///
  /// Example usage:
  /// ```dart
  /// await _increaseFrequency('exampleKey');
  /// ```
  Future<void> _increaseFrequency(String key) async {
    if (_freqBox.containsKey(key)) {
      final json = _freqBox.get(key);
      final item = json != null
          ? _CacheItem.fromJson(jsonDecode(json))
          : _CacheItem(frequency: 0, lastAccessed: DateTime.now());

      item.frequency++;
      item.lastAccessed = DateTime.now();

      await _freqBox.put(key, jsonEncode(item.toJson()));

      logger.i(
          'Frequency for key "$key" updated. New frequency: ${item.frequency}');
    }
  }

  /// Cleans up the cache by removing items that have exceeded their age limits.
  ///
  /// This method performs a cleanup operation on the cache by iterating through
  /// all keys in the cache and determining whether each item should be removed based
  /// on the last accessed time and predefined conditions. Items that are too old
  /// or have not been accessed recently are removed. After cleanup, the last cleanup
  /// date is updated and the next cleanup is scheduled.
  ///
  /// Workflow:
  /// 1. Get the current time.
  /// 2. Iterate through all keys in the cache and perform the following:
  ///    - Retrieve the corresponding cache item from the frequency box.
  ///    - If the item is not found, mark the key for removal.
  ///    - If the item is found, attempt to parse it into a `_CacheItem` object.
  ///    - If parsing fails, log the error and mark the key for removal.
  ///    - If parsing succeeds, check if the item should be removed based on
  ///      the cleanup period and max age conditions.
  /// 3. Filter out null values from the list of keys to remove.
  /// 4. Remove the items corresponding to the keys that need to be removed.
  /// 5. Update the last cleanup date to the current time.
  /// 6. Store the updated last cleanup date in the miscellaneous box.
  /// 7. Schedule the next cleanup operation.
  /// 8. Log the completion of the cache cleanup and the number of items removed.
  ///
  /// Parameters:
  /// - None
  ///
  /// Returns:
  /// - `Future<void>`: A `Future` that completes when the cache cleanup is done.
  ///
  /// Example usage:
  /// ```dart
  /// await _cleanupCache();
  /// ```
  Future<void> _cleanupCache() async {
    final now = DateTime.now();

    // Get the list of keys to remove based on the condition
    final itemsToRemove = await Future.wait(_cacheBox.keys.map((key) async {
      final itemValue = _freqBox.get(key);
      if (itemValue == null) return null;

      _CacheItem item;
      try {
        item = _CacheItem.fromJson(jsonDecode(itemValue));
      } catch (e, stackTrace) {
        logger.e('Error parsing _CacheItem for key $key: $e, $stackTrace');
        return key; // Mark for removal if parsing fails
      }

      // Determine if the item should be removed based on the conditions
      if (now.difference(item.lastAccessed) > _cacheConfig.cleanupPeriod ||
          now.difference(item.lastAccessed) >= _cacheConfig.maxAge) {
        return key;
      }
      return null;
    }));

    // Filter out null values and remove the items from the cache
    final keysToRemove = itemsToRemove.whereType<String>().toList();
    await Future.wait(keysToRemove.map(removeItem));

    // Update the last cleanup date
    _lastCleanupDate = now;
    await _miscBox.put('lastCleanupDate', now.toIso8601String());

    // Schedule the next cleanup
    _scheduleNextCleanup();

    logger.i('Cache cleanup completed. Removed ${keysToRemove.length} items.');
  }

  /// Makes space in the cache for a new item by removing the least valuable items if necessary.
  ///
  /// This method ensures that there is enough space in the cache for a new item of a given size.
  /// It calculates the current cache size and determines the target size that the cache should not exceed
  /// after adding the new item. If the current size exceeds the target size, it removes the least valuable
  /// items from the cache to free up space.
  ///
  /// Workflow:
  /// 1. Get the current cache size in bytes.
  /// 2. Calculate the target size by subtracting the new item size from the maximum cache size.
  /// 3. If the current cache size is less than or equal to the target size, return immediately as no removal is needed.
  /// 4. Otherwise, retrieve a list of the least valuable items to remove, based on the excess size.
  /// 5. Remove the items corresponding to the retrieved keys from the cache.
  ///
  /// Parameters:
  /// - `newItemSize`: The size of the new item to be added to the cache, in bytes.
  ///
  /// Returns:
  /// - `Future<void>`: A `Future` that completes when the necessary space has been made in the cache.
  ///
  /// Example usage:
  /// ```dart
  /// await _makeSpaceForNewItem(newItemSize);
  /// ```
  Future<void> _makeSpaceForNewItem(int newItemSize) async {
    final currentSize = await _getCacheSizeInBytes();
    final targetSize = _cacheConfig.maxCacheSizeBytes - newItemSize;

    if (currentSize <= targetSize) return;

    final itemsToRemove =
        await _getLeastValuableItems((currentSize - targetSize).ceil());
    final keysToRemove = itemsToRemove.map((e) => e.key).toList();

    await Future.wait(keysToRemove.map((key) => removeItem(key)));
    // No need to check the cache size again, as we've removed enough items
  }

  /// Retrieves a list of the least valuable cache items to free up the specified number of bytes.
  ///
  /// This method identifies the least valuable items in the cache based on their frequency and age.
  /// It uses a priority queue to prioritize items with the lowest value, calculated as the frequency
  /// divided by the age (in days). The method continues to accumulate items until the total size
  /// of the items to remove reaches the specified number of bytes to free.
  ///
  /// Workflow:
  /// 1. Get the current time.
  /// 2. Initialize a priority queue to store cache items by their value (frequency / (age + 1)).
  /// 3. Retrieve all cache keys from the cache box.
  /// 4. Iterate through each cache key:
  ///    - Retrieve the corresponding frequency box entry.
  ///    - If the entry exists, parse it into a `_CacheItem` object.
  ///    - Calculate the item's age in days and its value.
  ///    - Add the item to the priority queue.
  /// 5. Initialize an empty list to store the result and a counter for the total bytes to free.
  /// 6. While the total bytes are less than the specified bytes to free and the priority queue is not empty:
  ///    - Remove the item with the lowest value from the priority queue.
  ///    - Retrieve the corresponding cache item from the cache box.
  ///    - If the cache item exists, add its size to the total bytes and add the item to the result list.
  /// 7. Return the list of the least valuable items.
  ///
  /// Parameters:
  /// - `bytesToFree`: The number of bytes to free in the cache.
  ///
  /// Returns:
  /// - `Future<List<MapEntry<String, double>>>`: A `Future` that resolves to a list of the least valuable items
  ///   as key-value pairs, where the key is the cache item's key and the value is its calculated value.
  ///
  /// Example usage:
  /// ```dart
  /// List<MapEntry<String, double>> itemsToRemove = await _getLeastValuableItems(1024);
  /// ```
  Future<List<MapEntry<String, double>>> _getLeastValuableItems(
      int bytesToFree) async {
    final now = DateTime.now();
    final priorityQueue = PriorityQueue<MapEntry<String, double>>(
        (a, b) => a.value.compareTo(b.value));
    final cacheKeys = _cacheBox.keys.toList();

    for (final key in cacheKeys) {
      final freqBoxEntry = _freqBox.get(key);
      if (freqBoxEntry != null) {
        final item = _CacheItem.fromJson(jsonDecode(freqBoxEntry));
        final age = now.difference(item.lastAccessed).inDays;
        final value = item.frequency / (age + 1);
        priorityQueue.add(MapEntry(key, value));
      }
    }

    final result = <MapEntry<String, double>>[];
    int totalBytes = 0;

    while (totalBytes < bytesToFree && !priorityQueue.isEmpty) {
      final entry = priorityQueue.removeFirst();
      final _CacheItem = _cacheBox.get(entry.key);
      if (_CacheItem != null) {
        totalBytes += _CacheItem.length;
        result.add(entry);
      }
    }

    return result;
  }

  /// Removes an item from the cache and frequency boxes.
  ///
  /// This method deletes the specified item from both the `_cacheBox` and `_freqBox` if they contain the item.
  /// After successfully removing the item, a log message is recorded.
  ///
  /// Workflow:
  /// 1. Check if the `_cacheBox` contains the item with the given key. If so, delete it.
  /// 2. Check if the `_freqBox` contains the item with the given key. If so, delete it.
  /// 3. Log a message indicating that the item has been removed from the cache.
  ///
  /// Parameters:
  /// - `key`: The key of the item to be removed from the cache.
  ///
  /// Returns:
  /// - `Future<void>`: A `Future` that completes when the item has been removed from the cache.
  ///
  /// Example usage:
  /// ```dart
  /// await removeItem('example_key');
  /// ```
  ///
  Future<void> removeItem(String key) async {
    if (_cacheBox.containsKey(key)) {
      await _cacheBox.delete(key);
    }
    if (_freqBox.containsKey(key)) {
      await _freqBox.delete(key);
    }
    logger.i('Removed item from cache: $key');
  }

  /// Calculates the total size of the current cache in bytes.
  ///
  /// This method iterates through all values stored in the `_cacheBox` and sums their sizes to compute
  /// the total size of the cache in bytes.
  ///
  /// Workflow:
  /// 1. Initialize a counter (`totalSize`) to zero.
  /// 2. Iterate through all values in the `_cacheBox`.
  /// 3. For each value, add its length (size in bytes) to the counter.
  /// 4. Return the total size of the cache in bytes.
  ///
  /// Parameters:
  /// - None
  ///
  /// Returns:
  /// - `Future<int>`: A `Future` that resolves to the total size of the cache in bytes.
  ///
  /// Example usage:
  /// ```dart
  /// int cacheSize = await _getCacheSizeInBytes();
  /// ```
  ///
  Future<int> _getCacheSizeInBytes() async {
    int totalSize = 0;
    for (final value in _cacheBox.values) {
      totalSize += value.length;
    }
    return totalSize;
  }

  /// Clears all data from the cache, frequency, and miscellaneous boxes.
  ///
  /// This method attempts to clear the contents of the `_cacheBox`, `_freqBox`, and `_miscBox`
  /// if they are open. If any of the boxes are not open, they are skipped. After successfully
  /// clearing the boxes, a log message is recorded. If an error occurs during the clearing
  /// process, the error is logged.
  ///
  /// Workflow:
  /// 1. Check if the `_cacheBox` is open. If so, clear its contents.
  /// 2. Check if the `_freqBox` is open. If so, clear its contents.
  /// 3. Check if the `_miscBox` is open. If so, clear its contents.
  /// 4. Log a message indicating that the cache has been cleared.
  /// 5. If an error occurs during any of the clearing operations, catch the exception and log the error.
  ///
  /// Parameters:
  /// - None
  ///
  /// Returns:
  /// - `Future<void>`: A `Future` that completes when the cache clearing process is done.
  ///
  /// Example usage:
  /// ```dart
  /// await clearCache();
  /// ```
  Future<void> clearCache() async {
    try {
      if (_cacheBox.isOpen) {
        await _cacheBox.clear();
      }
      if (_freqBox.isOpen) {
        await _freqBox.clear();
      }
      if (_miscBox.isOpen) {
        await _miscBox.clear();
      }
      logger.i('Cache cleared');
    } catch (e, stackTrace) {
      logger.e('error while cleaning up data: $e, $stackTrace');
    }
  }

  /// Schedules the next cleanup operation for the cache.
  ///
  /// This method determines whether an immediate cleanup is necessary or if it should be scheduled for a future time.
  /// It also checks for old items in the cache and removes them if they have exceeded their maximum age.
  ///
  /// Workflow:
  /// 1. Get the current time.
  /// 2. Calculate the next cleanup time based on the last cleanup date and cleanup period.
  /// 3. Check if a cleanup is due. If yes, trigger an immediate cleanup.
  /// 4. If not, schedule a timer to trigger the cleanup at the next cleanup time.
  /// 5. Check and clean up old items based on their maximum age.
  ///
  /// Parameters:
  /// - None
  ///
  /// Returns:
  /// - void
  void _scheduleNextCleanup() {
    final now = DateTime.now();
    final nextCleanup =
        _lastCleanupDate?.add(_cacheConfig.cleanupPeriod) ?? now;

    if (_isCleanupDue(nextCleanup, now)) {
      _cleanupCache();
    } else {
      _scheduleTimerForNextCleanup(nextCleanup, now);
    }

    _checkAndCleanUpOldItems(now);
  }

  /// Checks if a cleanup is due based on the next cleanup time and the current time.
  ///
  /// Parameters:
  /// - `nextCleanup`: The next scheduled cleanup time.
  /// - `now`: The current time.
  ///
  /// Returns:
  /// - `bool`: True if cleanup is due, false otherwise.
  bool _isCleanupDue(DateTime nextCleanup, DateTime now) =>
      nextCleanup.isBefore(now);

  /// Schedules a timer to trigger the next cleanup operation.
  ///
  /// Parameters:
  /// - `nextCleanup`: The next scheduled cleanup time.
  /// - `now`: The current time.
  ///
  /// Returns:
  /// - void
  void _scheduleTimerForNextCleanup(DateTime nextCleanup, DateTime now) {
    Timer(nextCleanup.difference(now), _cleanupCache);
  }

  /// Checks and cleans up old items in the cache that have exceeded their maximum age.
  ///
  /// Workflow:
  /// 1. Check if the last max age check is null or if the current time exceeds the last max age check by the maximum age.
  /// 2. If true, update the last max age check to the current time and trigger the cleanup of old items.
  ///
  /// Parameters:
  /// - `now`: The current time.
  ///
  /// Returns:
  /// - void
  void _checkAndCleanUpOldItems(DateTime now) {
    if (_lastMaxAgeCheck == null ||
        now.difference(_lastMaxAgeCheck!) >= _cacheConfig.maxAge) {
      _lastMaxAgeCheck = now;
      _cleanUpOldItems();
    }
  }

  /// Cleans up old items in the cache that have exceeded their maximum age.
  ///
  /// Workflow:
  /// 1. Get the current time.
  /// 2. Iterate through all cache keys and determine if the corresponding items have exceeded their maximum age.
  /// 3. Collect keys of items that need to be removed.
  /// 4. Remove the items from the cache and log the number of removed items.
  ///
  /// Parameters:
  /// - None
  ///
  /// Returns:
  /// - `Future<void>`: A `Future` that completes when the old items have been cleaned up.
  Future<void> _cleanUpOldItems() async {
    final now = DateTime.now();
    final itemsToRemove = _cacheBox.keys.where((key) {
      if (_freqBox.containsKey(key)) {
        final item = _CacheItem.fromJson(jsonDecode(_freqBox.get(key)!));
        return now.difference(item.lastAccessed) >= _cacheConfig.maxAge;
      } else {
        return false;
      }
    }).toList();

    await Future.wait(itemsToRemove.map((key) => removeItem(key)));
    logger.i('Expired items removed from cache: ${itemsToRemove.length}');
  }

  /// Preloads a list of image resources by caching them asynchronously.
  ///
  /// This function takes a list of [urls] representing image URLs and attempts
  /// to cache each image concurrently to improve loading times when they are
  /// later displayed in the app.
  ///
  /// Parameters:
  /// - [urls]: A list of strings containing URLs of images to be preloaded.
  ///
  /// Logging:
  /// Errors encountered during image caching are logged using a logger instance.
  ///
  /// Example usage:
  /// ```dart
  /// List<String> imageUrls = [
  ///   'https://example.com/image1.jpg',
  ///   'https://example.com/image2.jpg',
  ///   'https://example.com/image3.jpg',
  /// ];
  ///
  /// await preloadImageResources(imageUrls);
  /// ```
  Future<void> preloadImageResources(List<String> urls) async {
    Stopwatch stopwatch = Stopwatch()..start();
    await Future.wait(
      urls.map((url) => cacheImage(url)).toList().map(
        (future) {
          return future.catchError(
            (e, stackTrace) {
              logger.e('Error caching image: $e', stackTrace);
            },
          );
        },
      ),
    );
    stopwatch.stop();
    logger
        .d('images loaded: $urls in time ${stopwatch.elapsed.inMilliseconds}');
  }

  //------------------------------------------------------pdf---------------------------------------------------//

  /// Caches a PDF from a given URL.
  ///
  /// This function first checks if the PDF is already cached by hashing the URL and checking the cache.
  /// If the PDF is not cached, it fetches the PDF bytes from the network, checks if the file size is within the limit,
  /// and then caches the PDF. If there is not enough space in the cache, it makes space by removing the least recently used items.
  ///
  /// @param pdfUrl The URL of the PDF to cache.
  // Future<void> cachePDF(String pdfUrl) async {
  //   final hashedPdfUrl = EncryptionService.hashString(pdfUrl);

  //   try {
  //     if (!_cacheBox.containsKey(hashedPdfUrl)) {
  //       final fileBytes = await _fetchPDFBytesFromNetwork(pdfUrl);

  //       if (fileBytes != null && fileBytes.length <= _cacheConfig.maxFileSizeBytes) {
  //         if (await _hasSpaceInCache(fileBytes.length)) {
  //           await _cachePDF(hashedPdfUrl, fileBytes);
  //           logger.i('PDF cached successfully: $pdfUrl');
  //         } else {
  //           await _makeSpaceForNewItem(fileBytes.length);
  //           await _cachePDF(hashedPdfUrl, fileBytes);
  //           logger.i('PDF cached after cleanup: $pdfUrl');
  //         }
  //       } else {
  //         logger.i('File too large or failed to fetch: $pdfUrl');
  //       }
  //     }
  //   } catch (e, stackTrace) {
  //     logger.e('Failed to cache PDF: $pdfUrl, error: $e, $stackTrace');
  //   }
  // }

  // /// Caches a PDF in the cache box and updates the frequency box.
  // ///
  // /// This function stores the PDF bytes in the cache box with the hashed URL as the key.
  // /// It then updates the frequency box by storing a _CacheItem with the frequency set to 1 and the last accessed time set to the current time.
  // ///
  // /// @param hashedPdfUrl The hashed URL of the PDF to cache.
  // /// @param fileBytes The bytes of the PDF to cache.
  // Future<void> _cachePDF(String hashedPdfUrl, Uint8List fileBytes) async {
  //   await _cacheBox.put(hashedPdfUrl, fileBytes);
  //   await _increaseFrequency(hashedPdfUrl);
  //   await _freqBox.put(
  //       hashedPdfUrl,
  //       jsonEncode(
  //           _CacheItem(frequency: 1, lastAccessed: DateTime.now()).toJson()));
  // }

  // /// Fetches PDF bytes from the network.
  // ///
  // /// This function first checks if the PDF bytes are already cached in the network cache.
  // /// If not, it waits for any pending requests for the same URL, then sends a GET request to the URL.
  // /// If the request is successful, it caches the PDF bytes and returns them.
  // /// If the request fails, it retries up to a maximum number of times before returning null.
  // ///
  // /// @param pdfUrl The URL of the PDF to fetch.
  // /// @return The PDF bytes if the request is successful, null otherwise.
  // Future<Uint8List?> _fetchPDFBytesFromNetwork(String pdfUrl) async {
  //   final cachedBytes = _networkCache.get(pdfUrl);
  //   if (cachedBytes != null) {
  //     return cachedBytes;
  //   }

  //   await _waitForPendingRequest(pdfUrl);

  //   final updatedCachedBytes = _networkCache.get(pdfUrl);
  //   if (updatedCachedBytes != null) {
  //     return updatedCachedBytes;
  //   }

  //   _pendingRequests.add(pdfUrl);

  //   int retryCount = 0;
  //   Uint8List? pdfBytes;

  //   try {
  //     final dio = Dio();
  //     while (retryCount < _cacheConfig.maxRetries) {
  //       try {
  //         final response = await dio.get(pdfUrl,
  //             options: Options(responseType: ResponseType.bytes));
  //         if (response.statusCode == 200) {
  //           final contentType = response.headers['content-type'];
  //           if (contentType == null || contentType.isEmpty) {
  //             throw Exception('No Content-Type header found in response');
  //           }

  //           pdfBytes = Uint8List.fromList(response.data);

  //           _networkCache.put(pdfUrl, pdfBytes);
  //           break;
  //         } else {
  //           logger.i('Failed to load PDF: ${response.statusCode}');
  //           return null;
  //         }
  //       } catch (e) {
  //         logger.i('Error fetching PDF: $e');
  //       }

  //       retryCount++;
  //       if (retryCount < _cacheConfig.maxRetries) {
  //         await Future.delayed(_retryDelay);
  //       }
  //     }

  //     return pdfBytes;
  //   } finally {
  //     _pendingRequests.remove(pdfUrl);
  //   }
  // }

  // /// Gets a cached PDF or fetches it from the network if not cached.
  // ///
  // /// This function first checks if the PDF is cached in the cache box.
  // /// If it is, it increases the frequency of the PDF and returns a PdfView with the cached PDF bytes.
  // /// If not, it fetches the PDF bytes from the network, caches them, and returns a PdfView with the fetched PDF bytes.
  // /// If any error occurs, it returns a placeholder PDF.
  // ///
  // /// @param pdfUrl The URL of the PDF to get.
  // /// @return A PdfView with the PDF bytes if the PDF is cached or fetched successfully, a placeholder PDF otherwise.
  // Future<Object?> getCachedPDF(String? pdfUrl) async {
  //   if (pdfUrl == null) {
  //     return _getPlaceholderPdf();
  //   }

  //   final hashedPdfUrl = EncryptionService.hashString(pdfUrl);

  //   try {
  //     if (_cacheBox.containsKey(hashedPdfUrl)) {
  //       logger.i('PDF loaded from cache: $pdfUrl');
  //       await _increaseFrequency(hashedPdfUrl);
  //       return SfPdfViewer.memory(_cacheBox.get(hashedPdfUrl)!);

  //       // PdfView(
  //       //     controller: PdfController(
  //       //         document: PdfDocument.openData(_cacheBox.get(hashedPdfUrl)!)));
  //     } else {
  //       final pdfBytes = await _fetchPDFBytesFromNetwork(pdfUrl);
  //       if (pdfBytes != null) {
  //         await cachePDF(pdfUrl);
  //         return SfPdfViewer.memory(pdfBytes);

  //         // PdfView(
  //         //     controller:
  //         //         PdfController(document: PdfDocument.openData(pdfBytes)));
  //       } else {
  //         return _getPlaceholderPdf;
  //       }
  //     }
  //   } catch (e, stackTrace) {
  //     logger.e('Error loading PDF: $e, $stackTrace');
  //     return _getPlaceholderPdf;
  //   }
  // }

  // /// Gets a placeholder PDF.
  // ///
  // /// This function fetches a placeholder PDF from a URL and returns a PdfView with the fetched PDF bytes.
  // ///
  // /// @return A PdfView with the placeholder PDF bytes.
  // Future<SfPdfViewer> _getPlaceholderPdf() async {
  //   const placeholderPdfUrl =
  //       'https://www.adobe.com/support/products/enterprise/knowledgecenter/media/c4611_sample_explain.pdf';
  //   final dio = Dio();
  //   final response = await dio.get(placeholderPdfUrl,
  //       options: Options(responseType: ResponseType.bytes));
  //   final pdfBytes = Uint8List.fromList(response.data);
  //   return SfPdfViewer.memory(
  //     pdfBytes,
  //     onDocumentLoadFailed: (e) => print(e),
  //   );
  //   // PdfView(
  //   //     controller: PdfController(document: PdfDocument.openData(pdfBytes)));
  // }

  //---------------------in-memory storage-----------------------------------//

  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Returns a list of all items currently in the cache.
  List<Map<String, dynamic>> get memoryCache =>
      List.unmodifiable(_memoryCache.values.toList());

  // Adds a new item to the cache.
  ///
  /// [item] must contain an 'id' key with a unique identifier for the item.
  /// If an item with the same id already exists, a [StateError] will be thrown.
  bool addItem(Map<String, dynamic> item) {
    if (!item.containsKey('id')) {
      logger.e('Error: Item must contain an "id" key');
      return false;
    }

    String itemId = item['id'].toString();

    if (_memoryCache.containsKey(itemId)) {
      logger.e('Error: Item with id $itemId already exists');
      throw StateError('Item with id $itemId already exists');
    } else {
      _memoryCache[itemId] = item;
      logger.i('Added new item with id: $itemId');
    }
    return true;
  }

  /// Retrieves an item from the cache by its id.
  ///
  /// Returns `null` if no item with the given id exists in the cache.
  Map<String, dynamic>? getItem(String itemId) {
    return _memoryCache[itemId];
  }

  /// Checks if an item with the given id exists in the cache.
  bool containsItem(String itemId) {
    return _memoryCache.containsKey(itemId);
  }

  /// Updates an existing item in the cache.
  ///
  /// [item] must contain an 'id' key with the unique identifier of the item to update.
  /// If no item with the given id exists, a [StateError] will be thrown.
  bool updateItem(Map<String, dynamic> item) {
    if (!item.containsKey('id')) {
      logger.e('Error: Item must contain an "id" key');
      throw ArgumentError('Item must contain an "id" key');
    }

    String itemId = item['id'].toString();

    if (!_memoryCache.containsKey(itemId)) {
      logger.e('Error: Item with id $itemId does not exist in the cache');
      throw StateError('Item with id $itemId does not exist in the cache');
    } else {
      _memoryCache[itemId] = item;
      logger.i('Updated item with id: $itemId');
      return true;
    }
  }

  // Removes an item from the cache by its id.
  ///
  /// Returns `true` if the item was found and removed, `false` otherwise.
  bool removeItemFromMemory(String itemId) {
    final removed = _memoryCache.remove(itemId);
    if (removed != null) {
      logger.i('Removed item with id: $itemId');
      return true;
    } else {
      logger.w('No item found with id: $itemId');
      return false;
    }
  }

  /// Clears the entire cache, removing all items.
  void clearCacheFromMemory() {
    _memoryCache.clear();
    logger.i('Cache cleared');
  }

  //-------------pdf - bytes ---------------------//
  Future<void> cachePDF(String pdfUrl) async {
    final hashedPdfUrl = EncryptionService.hashString(pdfUrl);

    try {
      if (!_cacheBox.containsKey(hashedPdfUrl)) {
        final fileBytes = await _fetchPDFBytesFromNetwork(pdfUrl);

        if (fileBytes != null &&
            fileBytes.length <= _cacheConfig.maxFileSizeBytes) {
          if (await _hasSpaceInCache(fileBytes.length)) {
            await _cachePDF(hashedPdfUrl, fileBytes);
            logger.i('PDF cached successfully: $pdfUrl');
          } else {
            await _makeSpaceForNewItem(fileBytes.length);
            await _cachePDF(hashedPdfUrl, fileBytes);
            logger.i('PDF cached after cleanup: $pdfUrl');
          }
        } else {
          logger.i('File too large or failed to fetch: $pdfUrl');
        }
      }
    } catch (e, stackTrace) {
      logger.e('Failed to cache PDF: $pdfUrl, error: $e, $stackTrace');
    }
  }

  Future<void> _cachePDF(String hashedPdfUrl, Uint8List fileBytes) async {
    await _cacheBox.put(hashedPdfUrl, fileBytes);
    await _increaseFrequency(hashedPdfUrl);
    await _freqBox.put(
        hashedPdfUrl,
        jsonEncode(
            _CacheItem(frequency: 1, lastAccessed: DateTime.now()).toJson()));
  }

  Future<Uint8List?> _fetchPDFBytesFromNetwork(String pdfUrl) async {
    final cachedBytes = _networkCache.get(pdfUrl);
    if (cachedBytes != null) {
      return cachedBytes;
    }

    await _waitForPendingRequest(pdfUrl);

    final updatedCachedBytes = _networkCache.get(pdfUrl);
    if (updatedCachedBytes != null) {
      return updatedCachedBytes;
    }

    _pendingRequests.add(pdfUrl);

    int retryCount = 0;
    Uint8List? pdfBytes;

    try {
      final dio = Dio();
      while (retryCount < _cacheConfig.maxRetries) {
        try {
          final response = await dio.get(pdfUrl,
              options: Options(responseType: ResponseType.bytes));
          if (response.statusCode == 200) {
            final contentType = response.headers['content-type'];
            if (contentType == null || contentType.isEmpty) {
              throw Exception('No Content-Type header found in response');
            }

            pdfBytes = Uint8List.fromList(response.data);

            _networkCache.put(pdfUrl, pdfBytes);
            break;
          } else {
            logger.i('Failed to load PDF: ${response.statusCode}');
            return null;
          }
        } catch (e) {
          logger.i('Error fetching PDF: $e');
        }

        retryCount++;
        if (retryCount < _cacheConfig.maxRetries) {
          await Future.delayed(_retryDelay);
        }
      }

      return pdfBytes;
    } finally {
      _pendingRequests.remove(pdfUrl);
    }
  }

  Future<Uint8List?> getCachedPDF(String? pdfUrl) async {
    if (pdfUrl == null) {
      return null;
    }

    final hashedPdfUrl = EncryptionService.hashString(pdfUrl);

    try {
      if (_cacheBox.containsKey(hashedPdfUrl)) {
        logger.i('PDF loaded from cache: $pdfUrl');
        await _increaseFrequency(hashedPdfUrl);
        return _cacheBox.get(hashedPdfUrl);
      } else {
        final pdfBytes = await _fetchPDFBytesFromNetwork(pdfUrl);
        if (pdfBytes != null) {
          await cachePDF(pdfUrl);
          return pdfBytes;
        } else {
          return null;
        }
      }
    } catch (e, stackTrace) {
      logger.e('Error loading PDF: $e, $stackTrace');
      return null;
    }
  }
}
