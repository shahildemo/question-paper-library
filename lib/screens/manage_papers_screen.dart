import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/paper_model.dart';
import '../models/subject_model.dart';
import '../services/paper_management_service.dart';

class ManagePapersScreen extends StatefulWidget {
  final Subject subject;
  final List<Paper> papers;

  const ManagePapersScreen({
    super.key,
    required this.subject,
    required this.papers,
  });

  @override
  State<ManagePapersScreen> createState() => _ManagePapersScreenState();
}

class _ManagePapersScreenState extends State<ManagePapersScreen> {
  List<Paper> _papers = [];
  Set<String> _deletedPaperIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _deletedPaperIds = await PaperManagementService.getDeletedPaperIds();
    final customPapers = await PaperManagementService.getCustomPapersForSubject(widget.subject.id);
    
    setState(() {
      _papers = [...widget.papers, ...customPapers];
      _isLoading = false;
    });
  }

  Future<void> _deletePaper(Paper paper, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Paper'),
        content: Text('Are you sure you want to delete ${paper.year} question paper?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await PaperManagementService.deletePaper(paper);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paper deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete paper'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _restorePaper(Paper paper, int index) async {
    await PaperManagementService.restorePaper(paper.id);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paper restored'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage - ${widget.subject.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Manage Papers'),
                  content: const Text(
                    '• Swipe left on a paper to delete it\n'
                    '• Deleted default papers can be restored\n'
                    '• Custom uploaded papers are permanently deleted',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _papers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No papers available',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _papers.length,
                  itemBuilder: (context, index) {
                    final paper = _papers[index];
                    final isDeleted = _deletedPaperIds.contains(paper.id);
                    final isCustom = paper.id.startsWith('custom_');

                    return Dismissible(
                      key: Key(paper.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        if (isDeleted) {
                          await _restorePaper(paper, index);
                          return false;
                        }
                        await _deletePaper(paper, index);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDeleted ? AppColors.success : AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDeleted ? Icons.restore : Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDeleted
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : isCustom
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isDeleted
                                  ? Icons.delete_outline
                                  : isCustom
                                      ? Icons.upload_file
                                      : Icons.description,
                              color: isDeleted
                                  ? AppColors.error
                                  : isCustom
                                      ? AppColors.success
                                      : AppColors.secondary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${paper.year} Question Paper',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDeleted ? AppColors.textSecondary : null,
                                ),
                              ),
                              if (isCustom) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Uploaded',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                paper.fileSize,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (isDeleted)
                                const Text(
                                  'Deleted - Swipe to restore',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                            ],
                          ),
                          trailing: isDeleted
                              ? TextButton(
                                  onPressed: () => _restorePaper(paper, index),
                                  child: const Text('Restore'),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: AppColors.error,
                                  onPressed: () => _deletePaper(paper, index),
                                ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
