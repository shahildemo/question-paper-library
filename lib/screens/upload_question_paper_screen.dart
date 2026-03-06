import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../constants/app_colors.dart';
import '../services/github_service.dart';
import 'github_settings_screen.dart';

/// Standalone upload screen — Faculty → Year → Semester → Subject → Exam Year → PDF
/// No dependency on NavigationProvider; works independently from any screen.
class UploadQuestionPaperScreen extends StatefulWidget {
  const UploadQuestionPaperScreen({super.key});

  @override
  State<UploadQuestionPaperScreen> createState() =>
      _UploadQuestionPaperScreenState();
}

class _UploadQuestionPaperScreenState extends State<UploadQuestionPaperScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _examYearController = TextEditingController(
    text: DateTime.now().year.toString(),
  );

  String? _selectedFaculty;
  String? _selectedYear;
  String? _selectedSemester;
  File? _selectedFile;
  int? _fileSizeBytes;

  bool _isUploading = false;
  bool _isCheckingDuplicate = false;
  bool _isDuplicate = false;
  double _uploadProgress = 0; // 0.0–1.0
  String _uploadStatus = '';
  bool _isGitHubConfigured = false;
  bool _previewVisible = false;

  // Auto-suggestions
  List<String> _subjectSuggestions = [];
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _checkGitHub();
  }

  Future<void> _checkGitHub() async {
    final ok = await GitHubService.isConfigured();
    setState(() => _isGitHubConfigured = ok);
  }

  // ─── Subject suggestions ───────────────────────────────────────────────

  Future<void> _loadSuggestions() async {
    if (_selectedFaculty == null ||
        _selectedYear == null ||
        _selectedSemester == null) {
      return;
    }
    setState(() => _loadingSuggestions = true);
    final suggestions = await GitHubService.fetchSubjectSuggestions(
      faculty: _selectedFaculty!,
      year: _selectedYear!,
      semester: _selectedSemester!,
    );
    setState(() {
      _subjectSuggestions = suggestions;
      _loadingSuggestions = false;
    });
  }

  // ─── Duplicate check ───────────────────────────────────────────────────

  Future<void> _checkDuplicate() async {
    if (_selectedFaculty == null ||
        _selectedYear == null ||
        _selectedSemester == null ||
        _subjectController.text.trim().isEmpty ||
        _examYearController.text.trim().isEmpty) {
      setState(() => _isDuplicate = false);
      return;
    }
    setState(() => _isCheckingDuplicate = true);
    final dup = await GitHubService.checkDuplicate(
      faculty: _selectedFaculty!,
      year: _selectedYear!,
      semester: _selectedSemester!,
      subject: _subjectController.text.trim(),
      examYear: _examYearController.text.trim(),
    );
    setState(() {
      _isDuplicate = dup;
      _isCheckingDuplicate = false;
    });
  }

  // ─── File picker ───────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          _selectedFile = file;
          _fileSizeBytes = result.files.single.size;
          _previewVisible = false;
        });
      }
    } catch (e) {
      _showSnack('Could not pick file: $e', error: true);
    }
  }

  // ─── Upload ────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      _showSnack('Please select a PDF file.', error: true);
      return;
    }
    if (!_isGitHubConfigured) {
      _showSnack(
        'Configure GitHub first (tap the cloud icon above).',
        error: true,
      );
      return;
    }
    if (_isDuplicate) {
      _showSnack(
        'This paper already exists. Remove the duplicate first.',
        error: true,
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Starting upload…';
    });

    final result = await GitHubService.uploadPaper(
      faculty: _selectedFaculty!,
      year: _selectedYear!,
      semester: _selectedSemester!,
      subject: _subjectController.text.trim(),
      examYear: _examYearController.text.trim(),
      pdfFile: _selectedFile!,
      onStatus: (s) {
        if (!mounted) return;
        setState(() {
          _uploadStatus = s;
          // Simulate step progress
          if (s.contains('Encoding')) _uploadProgress = 0.2;
          if (s.contains('Checking')) _uploadProgress = 0.3;
          if (s.contains('Uploading PDF')) _uploadProgress = 0.6;
          if (s.contains('metadata')) _uploadProgress = 0.9;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _uploadProgress = result.success ? 1.0 : 0;
      _uploadStatus = '';
    });

    if (result.success) {
      _showSnack('Paper uploaded successfully! ✓');
      Navigator.pop(context, true);
    } else if (result.isDuplicate) {
      setState(() => _isDuplicate = true);
      _showSnack(result.message, error: true);
    } else {
      _showSnack(result.message, error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _examYearController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Question Paper'),
        actions: [
          IconButton(
            icon: Icon(
              _isGitHubConfigured ? Icons.cloud_done : Icons.cloud_off,
              color: _isGitHubConfigured ? AppColors.success : AppColors.error,
            ),
            tooltip: 'GitHub Cloud Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GitHubSettingsScreen()),
              );
              _checkGitHub();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GitHub status banner
              if (!_isGitHubConfigured) _ConfigBanner(),
              if (!_isGitHubConfigured) const SizedBox(height: 16),

              // Upload Progress
              if (_isUploading) ...[
                _UploadProgressCard(
                  progress: _uploadProgress,
                  status: _uploadStatus,
                ),
                const SizedBox(height: 20),
              ],

              // ── Step 1: Faculty ──
              _SectionLabel(step: '1', label: 'Select Faculty'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedFaculty,
                decoration: _inputDeco(
                  hint: 'Choose faculty',
                  icon: Icons.school_outlined,
                ),
                items: GitHubService.faculties
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedFaculty = v;
                    _selectedYear = null;
                    _selectedSemester = null;
                    _subjectSuggestions = [];
                    _isDuplicate = false;
                  });
                },
                validator: (v) => v == null ? 'Select a faculty' : null,
              ),
              const SizedBox(height: 20),

              // ── Step 2: Year ──
              _SectionLabel(step: '2', label: 'Select Year'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedYear,
                decoration: _inputDeco(
                  hint: 'Choose year',
                  icon: Icons.calendar_today_outlined,
                ),
                items: GitHubService.years
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedYear = v;
                    _selectedSemester = null;
                    _subjectSuggestions = [];
                    _isDuplicate = false;
                  });
                },
                validator: (v) => v == null ? 'Select a year' : null,
              ),
              const SizedBox(height: 20),

              // ── Step 3: Semester ──
              _SectionLabel(step: '3', label: 'Select Semester'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedSemester,
                decoration: _inputDeco(
                  hint: 'Choose semester',
                  icon: Icons.view_agenda_outlined,
                ),
                items: GitHubService.semesters
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedSemester = v;
                    _isDuplicate = false;
                  });
                  _loadSuggestions();
                },
                validator: (v) => v == null ? 'Select a semester' : null,
              ),
              const SizedBox(height: 20),

              // ── Step 4: Subject ──
              _SectionLabel(step: '4', label: 'Enter Subject'),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _subjectSuggestions;
                  }
                  return _subjectSuggestions.where(
                    (s) => s.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: (v) {
                  _subjectController.text = v;
                  _checkDuplicate();
                },
                fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmitted) {
                  // Sync controllers
                  textCtrl.text = _subjectController.text;
                  textCtrl.addListener(() {
                    _subjectController.text = textCtrl.text;
                  });
                  return TextFormField(
                    controller: textCtrl,
                    focusNode: focusNode,
                    decoration: _inputDeco(
                      hint: 'e.g. Data Structures',
                      icon: Icons.book_outlined,
                      suffix: _loadingSuggestions
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() => _isDuplicate = false),
                    onEditingComplete: _checkDuplicate,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter the subject name'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Step 5: Exam Year ──
              _SectionLabel(step: '5', label: 'Enter Exam Year'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _examYearController,
                decoration: _inputDeco(
                  hint: 'e.g. 2023',
                  icon: Icons.event_outlined,
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (_) => setState(() => _isDuplicate = false),
                onEditingComplete: _checkDuplicate,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter exam year';
                  final y = int.tryParse(v.trim());
                  if (y == null || y < 2000 || y > DateTime.now().year + 1) {
                    return 'Enter a valid year (e.g. 2023)';
                  }
                  return null;
                },
              ),

              // Duplicate warning
              if (_isCheckingDuplicate)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Checking for duplicates…',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isDuplicate && !_isCheckingDuplicate)
                _DuplicateWarning(
                  faculty: _selectedFaculty ?? '',
                  year: _selectedYear ?? '',
                  semester: _selectedSemester ?? '',
                  subject: _subjectController.text,
                  examYear: _examYearController.text,
                ),
              const SizedBox(height: 24),

              // ── Step 6: PDF File ──
              _SectionLabel(step: '6', label: 'Upload PDF'),
              const SizedBox(height: 8),
              _FilePicker(
                selectedFile: _selectedFile,
                fileSizeBytes: _fileSizeBytes,
                onTap: _pickFile,
              ),
              const SizedBox(height: 12),

              // PDF Preview toggle
              if (_selectedFile != null) ...[
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _previewVisible = !_previewVisible),
                      icon: Icon(
                        _previewVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      label: Text(
                        _previewVisible ? 'Hide Preview' : 'Preview PDF',
                      ),
                    ),
                  ],
                ),
                if (_previewVisible) _PdfPreview(file: _selectedFile!),
              ],
              const SizedBox(height: 32),

              // ── Metadata path preview ──
              if (_selectedFaculty != null &&
                  _selectedYear != null &&
                  _selectedSemester != null &&
                  _subjectController.text.trim().isNotEmpty &&
                  _examYearController.text.trim().isNotEmpty)
                _PathPreview(
                  path: GitHubService.buildFilePath(
                    faculty: _selectedFaculty!,
                    year: _selectedYear!,
                    semester: _selectedSemester!,
                    subject: _subjectController.text.trim(),
                    examYear: _examYearController.text.trim(),
                  ),
                ),
              const SizedBox(height: 24),

              // ── Upload button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isUploading || _isDuplicate) ? null : _upload,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isUploading
                        ? _uploadStatus.isNotEmpty
                              ? _uploadStatus
                              : 'Uploading…'
                        : 'Upload Paper',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: _isDuplicate
                        ? AppColors.error
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.error.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String step;
  final String label;

  const _SectionLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  final double progress;
  final String status;

  const _UploadProgressCard({required this.progress, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.isNotEmpty ? status : 'Uploading…',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  final File? selectedFile;
  final int? fileSizeBytes;
  final VoidCallback onTap;

  const _FilePicker({
    required this.selectedFile,
    required this.fileSizeBytes,
    required this.onTap,
  });

  String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final picked = selectedFile != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: picked ? AppColors.success : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: picked
              ? AppColors.success.withValues(alpha: 0.07)
              : AppColors.background,
        ),
        child: Column(
          children: [
            Icon(
              picked ? Icons.check_circle : Icons.upload_file,
              size: 46,
              color: picked ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              picked ? 'PDF Selected' : 'Tap to choose PDF',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: picked ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            if (picked) ...[
              const SizedBox(height: 4),
              Text(
                selectedFile!.path.split('/').last,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (fileSizeBytes != null)
                Text(
                  _fmt(fileSizeBytes!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  final File file;

  const _PdfPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SfPdfViewer.file(file, enableDoubleTapZooming: true),
    );
  }
}

class _PathPreview extends StatelessWidget {
  final String path;

  const _PathPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.folder_outlined, size: 16, color: AppColors.secondary),
              SizedBox(width: 6),
              Text(
                'Will be stored as',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            path,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateWarning extends StatelessWidget {
  final String faculty, year, semester, subject, examYear;

  const _DuplicateWarning({
    required this.faculty,
    required this.year,
    required this.semester,
    required this.subject,
    required this.examYear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Duplicate Paper Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$faculty › $year › $semester › $subject › $examYear already exists in the shared library.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GitHubSettingsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: const [
            Icon(Icons.warning_outlined, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'GitHub Cloud not configured. Tap here to set it up before uploading.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}
