import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/app_colors.dart';
import '../models/subject_model.dart';
import '../services/paper_management_service.dart';
import '../services/github_service.dart';

class UploadPaperScreen extends StatefulWidget {
  final Subject subject;

  const UploadPaperScreen({super.key, required this.subject});

  @override
  State<UploadPaperScreen> createState() => _UploadPaperScreenState();
}

class _UploadPaperScreenState extends State<UploadPaperScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  File? _selectedFile;
  bool _isUploading = false;
  int _selectedYear = DateTime.now().year;
  bool _shareToCloud = false;
  bool _isGitHubConfigured = false;
  String _uploadStatus = '';

  final List<int> _years = List.generate(
    10,
    (index) => DateTime.now().year - index,
  );

  @override
  void initState() {
    super.initState();
    _checkGitHub();
  }

  Future<void> _checkGitHub() async {
    final configured = await GitHubService.isConfigured();
    setState(() => _isGitHubConfigured = configured);
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadPaper() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Saving locally…';
    });

    try {
      // 1. Save locally
      final paper = await PaperManagementService.uploadPaper(
        subjectId: widget.subject.id,
        year: _selectedYear,
        pdfFile: _selectedFile!,
      );

      if (paper == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save paper locally'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 2. Optionally push to GitHub
      if (_shareToCloud && _isGitHubConfigured) {
        setState(() => _uploadStatus = 'Uploading to GitHub…');
        final result = await GitHubService.uploadPaperLegacy(
          facultyId: widget.subject.id.split('_').first,
          semesterId: widget.subject.id.split('_').length > 1
              ? widget.subject.id.split('_')[1]
              : widget.subject.id,
          subjectId: widget.subject.id,
          subjectName: widget.subject.name,
          year: _selectedYear,
          pdfFile: _selectedFile!,
          onStatus: (s) => setState(() => _uploadStatus = s),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.success
                  ? AppColors.success
                  : AppColors.warning,
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _shareToCloud && _isGitHubConfigured
                  ? 'Paper uploaded locally and shared to cloud!'
                  : 'Paper uploaded successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Question Paper')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subject',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subject.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.subject.code,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Year Selection
              const Text(
                'Exam Year',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // File Selection
              const Text(
                'PDF File',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPdfFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedFile != null
                          ? AppColors.success
                          : AppColors.border,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _selectedFile != null
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.background,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null
                            ? Icons.check_circle
                            : Icons.upload_file,
                        size: 48,
                        color: _selectedFile != null
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFile != null
                            ? 'File Selected'
                            : 'Tap to select PDF file',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedFile != null
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _selectedFile!.path.split('/').last,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Share to Cloud toggle
              if (_isGitHubConfigured)
                Card(
                  child: SwitchListTile(
                    title: const Text('Share to Cloud'),
                    subtitle: const Text(
                      'Upload to GitHub so all users can access this paper',
                    ),
                    secondary: const Icon(
                      Icons.cloud_upload,
                      color: AppColors.primary,
                    ),
                    value: _shareToCloud,
                    onChanged: (v) => setState(() => _shareToCloud = v),
                    activeColor: AppColors.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/github-settings'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.cloud_off, color: AppColors.info, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Set up GitHub Cloud to share papers with all users. Tap to configure.',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Upload Button
              if (_isUploading && _uploadStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _uploadStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadPaper,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Upload Paper',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
