import 'package:cache_service/src/services/cache_services/widgets/pdf/cache_pdf_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A widget that displays a PDF loaded from a URL, with caching support.
class CachedPDF extends StatefulWidget {
  /// The URL of the PDF to display.
  final String? pdfUrl;
  final Alignment alignment;
  final BoxFit fit;

  const CachedPDF({
    super.key,
    this.pdfUrl,
    this.alignment = Alignment.topCenter,
    this.fit = BoxFit.cover,
  });

  @override
  _CachedPDFState createState() => _CachedPDFState();
}

class _CachedPDFState extends State<CachedPDF> {
  CachedPDFProvider? _cachedPDFProvider;

  /// Update provider if pdfUrl changes.
  @override
  void didUpdateWidget(CachedPDF oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfUrl != widget.pdfUrl) {
      _cachedPDFProvider = CachedPDFProvider(widget.pdfUrl);
    }
  }

  /// Initialize provider with pdfUrl.
  @override
  void initState() {
    super.initState();
    _cachedPDFProvider = CachedPDFProvider(widget.pdfUrl);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CachedPDFProvider>.value(
      value: _cachedPDFProvider!,
      child: Consumer<CachedPDFProvider>(
        builder: (context, cachedPDFProvider, child) {
          if (cachedPDFProvider.pdfView == null) {
            return Center(child: CircularProgressIndicator());
          }
          return Container(
            alignment: widget.alignment,
            child: cachedPDFProvider.pdfView,
          ); // Display PDF from provider.
        },
      ),
    );
  }
}
