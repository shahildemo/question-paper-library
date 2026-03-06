import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_strings.dart';
import '../models/paper_model.dart';
import '../providers/navigation_provider.dart';
import '../services/download_service.dart';
import '../widgets/paper_list_item.dart';
import 'pdf_viewer_screen.dart';

class PaperScreen extends StatefulWidget {
  const PaperScreen({super.key});

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  final Map<String, bool> _downloadedPapers = {};
  final Map<String, bool> _downloadingPapers = {};
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _checkDownloadedPapers();
  }

  Future<void> _checkDownloadedPapers() async {
    final navigation = context.read<NavigationProvider>();
    final subject = navigation.selectedSubject;
    if (subject == null) return;

    for (final paper in subject.papers) {
      final isDownloaded = await DownloadService.isFileDownloaded(paper.fileName);
      if (mounted) {
        setState(() {
          _downloadedPapers[paper.id] = isDownloaded;
        });
      }
    }
  }

  Future<void> _downloadPaper(Paper paper) async {
    setState(() {
      _downloadingPapers[paper.id] = true;
      _downloadProgress[paper.id] = 0;
    });

    final result = await DownloadService.downloadFile(
      sourcePath: paper.filePath,
      fileName: paper.fileName,
      isAsset: true,
      onProgress: (received, total) {
        if (total > 0 && mounted) {
          setState(() {
            _downloadProgress[paper.id] = received / total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloadingPapers[paper.id] = false;
        _downloadedPapers[paper.id] = result.success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _openDownloadedPaper(Paper paper) async {
    final filePath = await DownloadService.getDownloadedFilePath(paper.fileName);
    if (filePath != null) {
      try {
        await DownloadService.openFile(filePath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewPaper(Paper paper) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          paper: paper,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigation, child) {
        final faculty = navigation.selectedFaculty;
        final year = navigation.selectedYear;
        final semester = navigation.selectedSemester;
        final subject = navigation.selectedSubject;

        if (faculty == null ||
            year == null ||
            semester == null ||
            subject == null) {
          return const Scaffold(
            body: Center(
              child: Text('No subject selected'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(subject.name),
          ),
          body: subject.papers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        AppStrings.noPapersFound,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: subject.papers.length,
                  itemBuilder: (context, index) {
                    final paper = subject.papers[index];
                    return PaperListItem(
                      paper: paper,
                      isDownloaded: _downloadedPapers[paper.id] ?? false,
                      isDownloading: _downloadingPapers[paper.id] ?? false,
                      downloadProgress: _downloadProgress[paper.id] ?? 0,
                      onView: () => _viewPaper(paper),
                      onDownload: () => _downloadPaper(paper),
                      onOpen: () => _openDownloadedPaper(paper),
                    );
                  },
                ),
        );
      },
    );
  }
}
