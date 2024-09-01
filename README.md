# Cache Service
---

Cache Service is a powerful Flutter package designed to simplify and optimize the caching and display of images and PDFs in your mobile applications. With its robust caching strategies, including in-memory cache management and customizable settings, Cache Service helps reduce loading times, network requests, and resource usage, resulting in a seamless user experience.

## Features

- **CachedImage Widget**: Display images with built-in caching to reduce loading times and network requests.
- **CachedPDF Widget**: Display PDF files with caching support, ensuring fast loading and offline access.
- **Customizable Cache Settings**: Easily configure cache size, expiration policies, and more to fit your app's needs.
- **Shimmer Effect Support**: Provides a shimmer effect while loading assets, offering a smooth user experience.

## Installation

Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  cache_service: 1.0.1
```

Then, run:

```bash
flutter pub get
```

## Usage:

##### main.dart

In `main.dart` initialize `CacheService`:

```dart
void main() async {
  CacheService cacheService = CacheService();
  await cacheService.initialize();
  runApp(const MyApp());
}
```

##### alternatively, 
To override the default properties of the cache service, you can customize settings such as cache size, expiration policies, and more by configuring the package's settings.
```dart
void main() async {
  CacheService cacheService = CacheService();
  await cacheService.initialize(
      cacheConfig: CacheConfig(
    cleanupPeriod: const Duration(days: 10),
    maxAge: const Duration(days: 14),
    maxFileSizeBytes: 1024 * 1024 * 10, //indicating, 10 MB
    maxCacheSizeBytes: 1024 * 1024 * 50, //indicating, 50 MB
    maxRetries: 3,
  ));
  runApp(const MyApp());
}
```

### CachedImage Widget

The `CachedImage` widget makes it easy to display and cache images from the internet.

```dart
import 'package:cache_service/cache_service.dart';

CachedImage(
  imageUrl: 'https://example.com/image.jpg',
);
```

### CachedPDF Widget

Use the `CachedPDF` widget to display and cache PDF files, reducing load times and network usage.

```dart
import 'package:cache_service/cache_service.dart';

CachedPDF(
    pdfUrl: 'https://example.com/sample.pdf',
);
```

### Clearing cache

```dart
import 'package:cache_service/cache_service.dart';

InkWell(
    onTap: () {
    //clearing cache; this will clear all local cache (excluding in-memory cache)
    CacheService().clearCache();
    },
    child: const Text(
        'Clear cache',
        ),
    ),
```

### Preload cache
This function ` CacheService().preloadResources(['urls'])` can be used to pre load resources, which are going to be used later. This helps in improving customer experience. 

```dart
import 'package:cache_service/cache_service.dart';

InkWell(
    onTap: () {
     CacheService().preloadResources(['urls']);
    },
    child: const Text(
        'preload cache',
        ),
    ),
```


---
### In-memory cache
It is designed to manage in-memory caching. It allows efficient storage, retrieval, updating, and removal of cached items using a unique identifier. This service simplifies the management of in-memory data, making it easier to work with frequently accessed information and improving performance by reducing redundant operations.

##### Adding Items

Use the `addItem` method to add a new item to the cache.
```dart
CacheService().addItem({'id': 'item1', 'data': 'some data'});
```


##### Retrieving Items

To retrieve an item from the cache by its ID:
```dart
Map<String, dynamic>? item = CacheService().getItem('item1');
```

##### Checking Item Existence

Check if an item exists in the cache:
```dart
bool exists = CacheService().containsItem('item1');
```

##### Updating Items

Update an existing item in the cache. The item must contain the same 'id' key as the one to be updated.
```dart
CacheService().updateItem({'id': 'item1', 'data': 'updated data'});
```

##### Removing Items
Remove an item from the cache by its ID:
```dart
bool removed = CacheService().removeItemFromMemory('item1');
```

##### Clearing Cache
Clear all items from the cache:
```dart
CacheService().clearCacheFromMemory();
```

##### Accessing All Cached Items
Retrieve a list of all items currently stored in the cache:
```dart
List<Map<String, dynamic>> allItems = CacheService().memoryCache;
```

---

## Example

For a complete example, check out the [example](example/) directory, which demonstrates how to use the `CacheService()` in a real-world scenario.

## Contributing

Contributions are welcome! If you have any ideas, suggestions, or issues, feel free to open an issue or a pull request on GitHub.

## License

This project is licensed under the 3-Clause BSD License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this package useful, please consider giving it a star on GitHub. Your support is appreciated!
