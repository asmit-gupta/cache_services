import 'dart:typed_data';
import 'package:cache_service/src/services/cache_services/cache_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// A provider class for managing PDF loading and caching.
class CachedPDFProvider extends ChangeNotifier {
  SfPdfViewer? _pdfView; // Nullable initially

  /// Constructs a `CachedPDFProvider` instance and loads the PDF from [pdfUrl].
  CachedPDFProvider(String? pdfUrl) {
    _loadPDF(pdfUrl);
  }

  /// Retrieves the current PDF view.
  SfPdfViewer? get pdfView => _pdfView;

  /// Loads the PDF from [pdfUrl] asynchronously.
  Future<void> _loadPDF(String? pdfUrl) async {
    try {
      if (pdfUrl == null) {
        _setPDFView(
            await _getPlaceholderPDF()); // Set placeholder if no pdfUrl provided.
      } else {
        await CacheService().getCachedPDF(pdfUrl); // Retrieve cached PDF.
        // if (cachedPDF is SfPdfViewer) {
        //   _setPDFView(cachedPDF); // Set the retrieved PDF as the view.
        // } else {
        //   print('Cached PDF is not a PdfView');
        // }
      }
    } catch (e) {
      print('Error loading PDF: $e'); // Log error if PDF loading fails.
      _setPDFView(await _getPlaceholderPDF()); // Set placeholder PDF on error.
    }
  }

  /// Sets the current PDF view and notifies listeners of the change.
  void _setPDFView(SfPdfViewer pdfView) {
    _pdfView = pdfView; // Set the new PDF view.
    notifyListeners(); // Notify listeners of the change.
  }

  /// Retrieves a placeholder PDF view.
  Future<SfPdfViewer> _getPlaceholderPDF() async {
    const placeholderPdfUrl =
        'https://morth.nic.in/sites/default/files/dd12-13_0.pdf';
    final dio = Dio();
    final response = await dio.get(placeholderPdfUrl,
        options: Options(responseType: ResponseType.bytes));
    final pdfBytes = Uint8List.fromList(response.data);
    return SfPdfViewer.memory(pdfBytes);

    // PdfView(
    //     controller: PdfController(document: PdfDocument.openData(pdfBytes)));
  }
}
