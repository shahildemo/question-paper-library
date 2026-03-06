import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/paper_model.dart';
import '../providers/navigation_provider.dart';
import '../services/download_service.dart';
import '../services/paper_management_service.dart';
import '../widgets/paper_list_item.dart';
import 'pdf_viewer_screen.dart';
import 'upload_paper_screen.dart';
import 'manage_papers_screen.dart';
import 'shared_papers_screen.dart';
import 'github_settings_screen.dart';

class PaperScreen extends StatefulWidget {
  const PaperScreen({super.key});

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, bool> _downloadedPapers = {};
  final Map<String, bool> _downloadingPapers = {};
  final Map<String, double> _downloadProgress = {};
  List<Paper> _allPapers = [];
  Set<String> _deletedPaperIds = {};
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await PaperManagementService.init();
    _deletedPaperIds = await PaperManagementService.getDeletedPaperIds();
    await _loadPapers();
    await _checkDownloadedPapers();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadPapers() async {
    final navigation = context.read<NavigationProvider>();
    final subject = navigation.selectedSubject;
    if (subject == null) return;

    final customPapers = await PaperManagementService.getCustomPapersForSubject(subject.id);
    setState(() {
      _allPapers = [...subject.papers, ...customPapers];
    });
  }

  Future<void> _checkDownloadedPapers() async {
    for (final paper in _allPapers) {
      final isDownloaded = await DownloadService.isFileDownloaded(paper.fileName);
      if (mounted) {
        setState(() {
          _downloadedPapers[paper.id] = isDownloaded;
        });
      }
    }
  }

  void _goToUpload() async {
    final navigation = context.read<NavigationProvider>();
    final subject = navigation.selectedSubject;
    if (subject == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadPaperScreen(subject: subject),
      ),
    );

    if (result == true) {
      await _loadPapers();
    }
  }

  void _goToManage() async {
    final navigation = context.read<NavigationProvider>();
    final subject = navigation.selectedSubject;
    if (subject == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagePapersScreen(
          subject: subject,
          papers: _allPapers,
        ),
      ),
    );

    await _loadData();
  }

  Future<void> _downloadPaper(Paper paper) async {
    setState(() {
      _downloadingPapers[paper.id] = true;
      _downloadProgress[paper.id] = 0;
    });

    // Check if it's a custom paper or default paper
    final isCustomPaper = paper.id.startsWith('custom_');
    
    if (isCustomPaper) {
      // For custom papers, copy from local storage to downloads
      final result = await DownloadService.downloadFile(
        sourcePath: paper.filePath,
        fileName: paper.fileName,
        isAsset: false, // Not an asset, it's a local file
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
      return;
    }

    // For default papers, copy from assets
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

        // Filter out deleted papers
        final visiblePapers = _allPapers.where((p) => !_deletedPaperIds.contains(p.id)).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(subject.name),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.phone_android, size: 18), text: 'Local'),
                Tab(icon: Icon(Icons.cloud, size: 18), text: 'Shared'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.cloud_outlined),
                tooltip: 'GitHub Cloud Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GitHubSettingsScreen(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Manage Papers',
                onPressed: _goToManage,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _goToUpload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Local Papers ──
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visiblePapers.isEmpty
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
                          itemCount: visiblePapers.length,
                          itemBuilder: (context, index) {
                            final paper = visiblePapers[index];
                            return PaperListItem(
                              paper: paper,
                              isDownloaded: _downloadedPapers[paper.id] ?? false,
                              isDownloading:
                                  _downloadingPapers[paper.id] ?? false,
                              downloadProgress:
                                  _downloadProgress[paper.id] ?? 0,
                              onView: () => _viewPaper(paper),
                              onDownload: () => _downloadPaper(paper),
                              onOpen: () => _openDownloadedPaper(paper),
                            );
                          },
                        ),

              // ── Tab 2: Shared (GitHub Cloud) Papers ──
              SharedPapersScreen(
                subjectId: subject.id,
                subjectName: subject.name,
              ),
            ],
          ),
        );
      },
    );
  }
}
