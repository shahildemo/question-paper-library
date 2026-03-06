import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../constants/app_colors.dart';
import '../services/github_service.dart';

class SharedPapersScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SharedPapersScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SharedPapersScreen> createState() => _SharedPapersScreenState();
}

class _SharedPapersScreenState extends State<SharedPapersScreen> {
  List<SharedPaperEntry> _papers = [];
  bool _isLoading = true;
  bool _isConfigured = false;
  final Map<String, bool> _downloading = {};
  final Map<String, String> _cachedPaths = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _isConfigured = await GitHubService.isConfigured();
    if (_isConfigured) {
      await _fetchPapers();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPapers() async {
    setState(() => _isLoading = true);
    final papers = await GitHubService.fetchSharedPapers(
        subjectId: widget.subjectId);
    setState(() {
      _papers = papers;
      _isLoading = false;
    });
  }

  Future<void> _viewPaper(SharedPaperEntry entry) async {
    if (_cachedPaths.containsKey(entry.fileName)) {
      _openPdfViewer(_cachedPaths[entry.fileName]!);
      return;
    }
    setState(() => _downloading[entry.fileName] = true);
    final path = await GitHubService.downloadSharedPaper(entry);
    setState(() => _downloading[entry.fileName] = false);
    if (path != null) {
      _cachedPaths[entry.fileName] = path;
      _openPdfViewer(path);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to download paper'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _openPdfViewer(String filePath) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _SharedPdfViewer(filePath: filePath),
    ));
  }

  Future<void> _deletePaper(SharedPaperEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shared Paper'),
        content: Text(
            'Delete "${entry.subjectName} ${entry.year}" from the shared library? This affects all users.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await GitHubService.deleteSharedPaper(entry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? AppColors.success : AppColors.error,
        ));
        if (result.success) await _fetchPapers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shared Papers – ${widget.subjectName}'),
        actions: [
          if (_isConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchPapers,
            ),
        ],
      ),
      body: !_isConfigured
          ? _NotConfiguredView()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _papers.isEmpty
                  ? _EmptyView(onRefresh: _fetchPapers)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _papers.length,
                      itemBuilder: (context, index) {
                        final paper = _papers[index];
                        final isDownloading =
                            _downloading[paper.fileName] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.cloud,
                                          color: AppColors.primary,
                                          size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${paper.year} Question Paper',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Shared on ${paper.uploadedAt.substring(0, 10)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error),
                                      onPressed: () =>
                                          _deletePaper(paper),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloading
                                        ? null
                                        : () => _viewPaper(paper),
                                    icon: isDownloading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white))
                                        : const Icon(Icons.visibility,
                                            size: 18),
                                    label: Text(isDownloading
                                        ? 'Loading…'
                                        : 'View Paper'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _NotConfiguredView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off,
                size: 72, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              'GitHub Cloud Not Configured',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Set up GitHub cloud in Settings to browse and share question papers with all users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/github-settings');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_queue,
              size: 72, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No shared papers yet',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a paper from the subject page to share it with all users.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

// ─── Simple PDF viewer for shared papers ─────────────────────────────────────

class _SharedPdfViewer extends StatelessWidget {
  final String filePath;

  const _SharedPdfViewer({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Paper')),
      body: SfPdfViewer.file(
        File(filePath),
        enableDoubleTapZooming: true,
      ),
    );
  }
}
