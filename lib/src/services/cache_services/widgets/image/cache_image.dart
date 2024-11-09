import 'package:cache_service/src/services/cache_services/widgets/image/cache_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// A widget that displays a cached image with optional shimmer effect while loading.
///
/// This widget uses [CachedImageProvider] to handle image loading and caching.
/// It provides a shimmer effect or a placeholder image while the actual image is loading.
class CachedImage extends StatefulWidget {
  /// The URL of the image to be displayed.
  final String? imageUrl;

  /// The alignment of the image within its bounds.
  final Alignment alignment;

  /// How the image should be inscribed into the space allocated during layout.
  final BoxFit fit;

  /// Whether to show a shimmer effect while the image is loading.
  final bool shimmer;

  /// The base color of the shimmer effect.
  final Color shimmerBaseColor;

  /// The highlight color of the shimmer effect.
  final Color shimmerHighlightColor;

  /// Creates a [CachedImage] widget.
  ///
  /// The [imageUrl] is the URL of the image to be displayed.
  /// If [shimmer] is true, a shimmer effect will be shown while the image is loading.
  /// The [shimmerBaseColor] and [shimmerHighlightColor] control the colors of the shimmer effect.
  const CachedImage({
    super.key,
    this.imageUrl,
    this.alignment = Alignment.topCenter,
    this.fit = BoxFit.cover,
    this.shimmer = true,
    this.shimmerBaseColor = const Color(0xFFD0D0D0),
    this.shimmerHighlightColor = const Color.fromARGB(255, 164, 163, 163),
  });

  @override
  // ignore: library_private_types_in_public_api
  _CachedImageState createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  /// The provider that handles image loading and caching.
  CachedImageProvider? _cachedImageProvider;

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate the image provider if the URL has changed.
    if (oldWidget.imageUrl != widget.imageUrl) {
      _cachedImageProvider = CachedImageProvider(widget.imageUrl);
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize the image provider.
    _cachedImageProvider = CachedImageProvider(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _cachedImageProvider!,
      child: Consumer<CachedImageProvider>(
        builder: (context, cachedImageProvider, child) {
          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (cachedImageProvider.isLoading)
                widget.shimmer
                    ? Shimmer.fromColors(
                        baseColor: widget.shimmerBaseColor,
                        highlightColor: widget.shimmerHighlightColor,
                        child: Container(
                          color: Colors.white,
                        ),
                      )
                    : _buildPlaceholderImage(),
              if (!cachedImageProvider.isLoading)
                _buildImage(cachedImageProvider),
            ],
          );
        },
      ),
    );
  }

  /// Builds and returns a placeholder image widget.
  ///
  /// This is displayed when shimmer effect is disabled and the image is still loading.
  Widget _buildPlaceholderImage() {
    return Image(
      alignment: widget.alignment,
      fit: widget.fit,
      image: CachedImageProvider.getPlaceholderImage(),
    );
  }

  /// Builds and returns the main image widget.
  ///
  /// This method creates an [Image] widget with a frame builder for smooth loading transition.
  ///
  /// [cachedImageProvider] is the provider that supplies the image to be displayed.
  Widget _buildImage(CachedImageProvider cachedImageProvider) {
    return Image(
      alignment: widget.alignment,
      fit: widget.fit,
      image: cachedImageProvider.imageProvider,
      frameBuilder: (BuildContext context, Widget child, int? frame,
          bool wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          child: child,
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      },
    );
  }
}
