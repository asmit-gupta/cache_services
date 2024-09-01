import 'package:cache_service/src/services/cache_services/cache_service.dart';
import 'package:flutter/material.dart';

/// A provider class for managing image loading and caching.
///
/// This class extends [ChangeNotifier] to provide reactive updates
/// when the image loading state changes.
///
/// It handles loading images from a given URL, manages loading states,
/// and provides fallback to a placeholder image when necessary.
class CachedImageProvider extends ChangeNotifier {
  /// The current [ImageProvider] instance.
  ///
  /// This is either the loaded image, or a placeholder if the image
  /// is still loading or failed to load.
  ImageProvider _imageProvider = getPlaceholderImage();

  /// Indicates whether an image is currently being loaded.
  bool _isLoading = true;

  /// Constructs a [CachedImageProvider] instance and initiates image loading.
  ///
  /// [imageUrl] is the URL of the image to be loaded. If null, the placeholder
  /// image will be used.
  CachedImageProvider(String? imageUrl) {
    _loadImage(imageUrl);
  }

  /// Provides access to the current [ImageProvider].
  ///
  /// This getter returns the currently active [ImageProvider], which could
  /// be either the loaded image or the placeholder image.
  ImageProvider get imageProvider => _imageProvider;

  /// Indicates whether an image is currently being loaded.
  ///
  /// Returns `true` if an image is in the process of being loaded,
  /// `false` otherwise.
  bool get isLoading => _isLoading;

  /// Retrieves a placeholder image.
  ///
  /// This static method returns a [NetworkImage] that serves as a
  /// placeholder while the actual image is loading or if it fails to load.
  static ImageProvider getPlaceholderImage() {
    return const AssetImage('assets/placeholder_image.png');
  }

  /// Loads the image from the given [imageUrl] asynchronously.
  ///
  /// This method handles the image loading process:
  /// 1. Sets the loading state to true.
  /// 2. Attempts to load the image from the given URL.
  /// 3. If successful, sets the loaded image as the current image provider.
  /// 4. If unsuccessful (due to null URL or errors), sets the placeholder image.
  /// 5. Sets the loading state to false.
  /// 6. Notifies listeners of state changes.
  ///
  /// [imageUrl] is the URL of the image to be loaded. If null, the placeholder
  /// image will be used.
  Future<void> _loadImage(String? imageUrl) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (imageUrl == null) {
        _setImageProvider(getPlaceholderImage());
      } else {
        final cachedImage = await CacheService().getCachedImage(imageUrl);
        _setImageProvider(cachedImage);
      }
    } catch (e) {
      print('Error loading image: $e');
      _setImageProvider(getPlaceholderImage());
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sets the current image provider and notifies listeners of the change.
  ///
  /// This method updates the internal [_imageProvider] and notifies all
  /// listeners that the state has changed, triggering a rebuild of any
  /// dependent widgets.
  ///
  /// [imageProvider] is the new [ImageProvider] to be set.
  void _setImageProvider(ImageProvider imageProvider) {
    _imageProvider = imageProvider;
    notifyListeners();
  }
}
