import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/paper_model.dart';
import '../services/download_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final Paper paper;

  const PdfViewerScreen({
    super.key,
    required this.paper,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPdfPath;
  bool _isLoading = true;
  String? _error;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    try {
      // First check if file is already downloaded
      final downloadedPath = await DownloadService.getDownloadedFilePath(
        widget.paper.fileName,
      );

      if (downloadedPath != null) {
        setState(() {
          _localPdfPath = downloadedPath;
          _isLoading = false;
        });
        return;
      }

      // Otherwise, copy from assets to temp directory
      final tempPath = await DownloadService.copyAssetToTemp(
        widget.paper.filePath,
        widget.paper.fileName,
      );

      if (tempPath != null) {
        setState(() {
          _localPdfPath = tempPath;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load PDF';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.paper.year} Question Paper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25;
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _preparePdf,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_localPdfPath != null) {
      return SfPdfViewer.file(
        File(_localPdfPath!),
        controller: _pdfViewerController,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        onDocumentLoadFailed: (details) {
          setState(() {
            _error = 'Failed to load PDF: ${details.description}';
          });
        },
      );
    }

    return const Center(
      child: Text('No PDF available'),
    );
  }
}
