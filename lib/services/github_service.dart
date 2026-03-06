import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GitHubService
//
//  Repository layout (SmartQPaper structure):
//
//  SmartQPaper/
//    BCA/
//      Year2/
//        Semester3/
//          DataStructures/
//            2023.pdf
//    metadata/
//      index.json          ← full metadata list
// ─────────────────────────────────────────────────────────────────────────────

class GitHubService {
  static const String _baseUrl = 'https://api.github.com';

  // SharedPreferences keys
  static const String _tokenKey = 'github_token';
  static const String _repoOwnerKey = 'github_repo_owner';
  static const String _repoNameKey = 'github_repo_name';
  static const String _branchKey = 'github_branch';

  // Root folder inside the repo
  static const String _rootFolder = 'SmartQPaper';
  static const String _indexPath = 'SmartQPaper/metadata/index.json';

  // ─── Static lookup tables ──────────────────────────────────────────────

  static const List<String> faculties = ['BCA', 'BBS', 'BIT', 'BBA', 'CSIT'];

  static const List<String> years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  static const List<String> semesters = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  /// Convert display label → folder segment (no spaces / slashes)
  static String _slug(String label) =>
      label.replaceAll(RegExp(r'\s+'), '').replaceAll('/', '_');

  /// Build path:  SmartQPaper/BCA/Year2/Semester3/DataStructures/2023.pdf
  static String buildFilePath({
    required String faculty,
    required String year,
    required String semester,
    required String subject,
    required String examYear,
  }) {
    final sub = _slug(subject);
    final yr = _slug(year); // "2ndYear"
    final sem = _slug(semester); // "Semester3"
    return '$_rootFolder/$faculty/$yr/$sem/$sub/$examYear.pdf';
  }

  // ─── Config ───────────────────────────────────────────────────────────

  static Future<void> saveConfig({
    required String token,
    required String repoOwner,
    required String repoName,
    String branch = 'main',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_repoOwnerKey, repoOwner);
    await prefs.setString(_repoNameKey, repoName);
    await prefs.setString(_branchKey, branch);
  }

  static Future<Map<String, String?>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString(_tokenKey),
      'repoOwner': prefs.getString(_repoOwnerKey),
      'repoName': prefs.getString(_repoNameKey),
      'branch': prefs.getString(_branchKey) ?? 'main',
    };
  }

  static Future<bool> isConfigured() async {
    final c = await getConfig();
    return c['token'] != null &&
        c['repoOwner'] != null &&
        c['repoName'] != null;
  }

  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_repoOwnerKey);
    await prefs.remove(_repoNameKey);
    await prefs.remove(_branchKey);
  }

  // ─── HTTP helpers ──────────────────────────────────────────────────────

  static Map<String, String> _headers(String token) => {
    'Authorization': 'token $token',
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
  };

  // ─── Validate token ────────────────────────────────────────────────────

  static Future<GitHubResult> validateToken(String token) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: _headers(token),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return GitHubResult(
          success: true,
          message: 'Connected as ${data['login']}',
        );
      }
      return GitHubResult(
        success: false,
        message: 'Invalid token (${resp.statusCode})',
      );
    } catch (e) {
      return GitHubResult(success: false, message: 'Network error: $e');
    }
  }

  // ─── Duplicate detection ───────────────────────────────────────────────

  /// Returns true if a paper with same faculty/year/sem/subject/examYear exists.
  static Future<bool> checkDuplicate({
    required String faculty,
    required String year,
    required String semester,
    required String subject,
    required String examYear,
  }) async {
    final all = await fetchAllPapers();
    return all.any(
      (e) =>
          e.faculty == faculty &&
          e.year == year &&
          e.semester == semester &&
          e.subject.toLowerCase() == subject.toLowerCase() &&
          e.examYear == examYear,
    );
  }

  // ─── Upload paper ──────────────────────────────────────────────────────

  static Future<GitHubResult> uploadPaper({
    required String faculty,
    required String year,
    required String semester,
    required String subject,
    required String examYear,
    required File pdfFile,
    void Function(String status)? onStatus,
  }) async {
    try {
      onStatus?.call('Reading config…');
      final config = await getConfig();
      final token = config['token'];
      final owner = config['repoOwner'];
      final repo = config['repoName'];
      final branch = config['branch'] ?? 'main';

      if (token == null || owner == null || repo == null) {
        return GitHubResult(
          success: false,
          message: 'GitHub not configured. Go to Settings.',
        );
      }

      // ── Duplicate check ──
      onStatus?.call('Checking for duplicates…');
      final isDuplicate = await checkDuplicate(
        faculty: faculty,
        year: year,
        semester: semester,
        subject: subject,
        examYear: examYear,
      );
      if (isDuplicate) {
        return GitHubResult(
          success: false,
          isDuplicate: true,
          message:
              'A paper for $faculty › $year › $semester › $subject › $examYear already exists.',
        );
      }

      // ── Encode file ──
      onStatus?.call('Encoding file…');
      final bytes = await pdfFile.readAsBytes();
      final base64Content = base64Encode(bytes);
      final filePath = buildFilePath(
        faculty: faculty,
        year: year,
        semester: semester,
        subject: subject,
        examYear: examYear,
      );
      final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$filePath';

      // ── Check if already on GitHub (for SHA) ──
      String? existingSha;
      final checkResp = await http.get(
        Uri.parse(apiUrl),
        headers: _headers(token),
      );
      if (checkResp.statusCode == 200) {
        existingSha = json.decode(checkResp.body)['sha'] as String?;
      }

      // ── Upload PDF ──
      onStatus?.call('Uploading PDF to GitHub…');
      final uploadBody = json.encode({
        'message':
            'Upload $subject $examYear question paper ($faculty $year $semester)',
        'content': base64Content,
        'branch': branch,
        if (existingSha != null) 'sha': existingSha,
      });

      final uploadResp = await http.put(
        Uri.parse(apiUrl),
        headers: _headers(token),
        body: uploadBody,
      );

      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 201) {
        return GitHubResult(
          success: false,
          message: 'Upload failed (${uploadResp.statusCode})',
        );
      }

      final respData = json.decode(uploadResp.body);
      final downloadUrl = respData['content']['download_url'] as String;

      // ── Update metadata index ──
      onStatus?.call('Updating metadata index…');
      final entry = PaperMetadata(
        faculty: faculty,
        year: year,
        semester: semester,
        subject: subject,
        examYear: examYear,
        filePath: filePath,
        downloadUrl: downloadUrl,
        fileSize: _formatBytes(bytes.length),
        uploadedAt: DateTime.now().toIso8601String(),
        status: 'approved', // change to 'pending' if admin approval needed
      );
      await _updateIndex(
        token: token,
        owner: owner,
        repo: repo,
        branch: branch,
        entry: entry,
      );

      return GitHubResult(
        success: true,
        message: 'Paper uploaded! All users can now access it.',
        downloadUrl: downloadUrl,
        entry: entry,
      );
    } catch (e) {
      return GitHubResult(success: false, message: 'Upload error: $e');
    }
  }

  // ─── Index helpers ─────────────────────────────────────────────────────

  static Future<void> _updateIndex({
    required String token,
    required String owner,
    required String repo,
    required String branch,
    required PaperMetadata entry,
  }) async {
    final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$_indexPath';

    List<dynamic> existing = [];
    String? existingSha;

    final getResp = await http.get(Uri.parse(apiUrl), headers: _headers(token));
    if (getResp.statusCode == 200) {
      final data = json.decode(getResp.body);
      existingSha = data['sha'] as String?;
      final decoded = utf8.decode(
        base64Decode(data['content'].toString().replaceAll('\n', '')),
      );
      existing = json.decode(decoded) as List<dynamic>;
    }

    // Remove exact duplicate if re-uploading
    existing.removeWhere(
      (e) =>
          e['faculty'] == entry.faculty &&
          e['year'] == entry.year &&
          e['semester'] == entry.semester &&
          e['subject'] == entry.subject &&
          e['exam_year'] == entry.examYear,
    );
    existing.add(entry.toJson());

    final newContent = base64Encode(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(existing)),
    );

    await http.put(
      Uri.parse(apiUrl),
      headers: _headers(token),
      body: json.encode({
        'message': 'Update metadata index',
        'content': newContent,
        'branch': branch,
        if (existingSha != null) 'sha': existingSha,
      }),
    );
  }

  // ─── Fetch papers ──────────────────────────────────────────────────────

  static Future<List<PaperMetadata>> fetchAllPapers() async {
    try {
      final config = await getConfig();
      final token = config['token'];
      final owner = config['repoOwner'];
      final repo = config['repoName'];
      if (token == null || owner == null || repo == null) return [];

      final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$_indexPath';
      final resp = await http.get(Uri.parse(apiUrl), headers: _headers(token));
      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final decoded = utf8.decode(
        base64Decode(data['content'].toString().replaceAll('\n', '')),
      );
      final List<dynamic> list = json.decode(decoded);
      return list
          .map((e) => PaperMetadata.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<PaperMetadata>> fetchPapersForSubject({
    required String faculty,
    required String year,
    required String semester,
    required String subject,
  }) async {
    final all = await fetchAllPapers();
    return all
        .where(
          (e) =>
              e.faculty == faculty &&
              e.year == year &&
              e.semester == semester &&
              e.subject.toLowerCase() == subject.toLowerCase() &&
              e.status == 'approved',
        )
        .toList();
  }

  // ─── Subject auto-suggestions ──────────────────────────────────────────

  static Future<List<String>> fetchSubjectSuggestions({
    required String faculty,
    required String year,
    required String semester,
  }) async {
    final all = await fetchAllPapers();
    return all
        .where(
          (e) =>
              e.faculty == faculty && e.year == year && e.semester == semester,
        )
        .map((e) => e.subject)
        .toSet()
        .toList()
      ..sort();
  }

  // ─── Delete paper ──────────────────────────────────────────────────────

  static Future<GitHubResult> deletePaper(PaperMetadata entry) async {
    try {
      final config = await getConfig();
      final token = config['token'];
      final owner = config['repoOwner'];
      final repo = config['repoName'];
      final branch = config['branch'] ?? 'main';

      if (token == null || owner == null || repo == null) {
        return GitHubResult(success: false, message: 'GitHub not configured.');
      }

      final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/${entry.filePath}';

      // Get SHA
      final getResp = await http.get(
        Uri.parse(apiUrl),
        headers: _headers(token),
      );
      if (getResp.statusCode != 200) {
        return GitHubResult(
          success: false,
          message: 'File not found on GitHub.',
        );
      }
      final sha = json.decode(getResp.body)['sha'] as String;

      // Delete PDF
      final delResp = await http.delete(
        Uri.parse(apiUrl),
        headers: _headers(token),
        body: json.encode({
          'message': 'Delete ${entry.subject} ${entry.examYear} paper',
          'sha': sha,
          'branch': branch,
        }),
      );

      if (delResp.statusCode == 200) {
        await _removeFromIndex(
          token: token,
          owner: owner,
          repo: repo,
          branch: branch,
          entry: entry,
        );
        return GitHubResult(
          success: true,
          message: 'Paper deleted from shared library.',
        );
      }
      return GitHubResult(
        success: false,
        message: 'Delete failed (${delResp.statusCode})',
      );
    } catch (e) {
      return GitHubResult(success: false, message: 'Error: $e');
    }
  }

  static Future<void> _removeFromIndex({
    required String token,
    required String owner,
    required String repo,
    required String branch,
    required PaperMetadata entry,
  }) async {
    final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$_indexPath';
    final getResp = await http.get(Uri.parse(apiUrl), headers: _headers(token));
    if (getResp.statusCode != 200) return;

    final data = json.decode(getResp.body);
    final existingSha = data['sha'] as String;
    final decoded = utf8.decode(
      base64Decode(data['content'].toString().replaceAll('\n', '')),
    );
    final List<dynamic> existing = json.decode(decoded);

    existing.removeWhere(
      (e) =>
          e['faculty'] == entry.faculty &&
          e['year'] == entry.year &&
          e['semester'] == entry.semester &&
          e['subject'] == entry.subject &&
          e['exam_year'] == entry.examYear,
    );

    final newContent = base64Encode(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(existing)),
    );
    await http.put(
      Uri.parse(apiUrl),
      headers: _headers(token),
      body: json.encode({
        'message': 'Remove paper from index',
        'content': newContent,
        'branch': branch,
        'sha': existingSha,
      }),
    );
  }

  // ─── Download to cache ─────────────────────────────────────────────────

  static Future<String?> downloadPaper(
    PaperMetadata entry, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final config = await getConfig();
      final token = config['token']!;
      final owner = config['repoOwner']!;
      final repo = config['repoName']!;
      final branch = config['branch'] ?? 'main';

      final rawUrl =
          'https://raw.githubusercontent.com/$owner/$repo/$branch/${entry.filePath}';
      final rawResp = await http.get(
        Uri.parse(rawUrl),
        headers: _headers(token),
      );
      if (rawResp.statusCode != 200) return null;

      final cacheDir = Directory('${Directory.systemTemp.path}/qpl_cache');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final fileName =
          '${_slug(entry.faculty)}_${_slug(entry.year)}_${_slug(entry.semester)}_${_slug(entry.subject)}_${entry.examYear}.pdf';
      final file = File('${cacheDir.path}/$fileName');
      await file.writeAsBytes(rawResp.bodyBytes);
      onProgress?.call(rawResp.bodyBytes.length, rawResp.bodyBytes.length);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ─── Legacy compat: keep SharedPaperEntry working ─────────────────────

  static Future<List<SharedPaperEntry>> fetchSharedPapers({
    String? subjectId,
  }) async {
    final all = await fetchAllPapers();
    return all.map((e) => e.toSharedEntry()).toList();
  }

  static Future<GitHubResult> deleteSharedPaper(SharedPaperEntry entry) async {
    final meta = PaperMetadata(
      faculty: entry.facultyId,
      year: entry.semesterId,
      semester: entry.semesterId,
      subject: entry.subjectName,
      examYear: entry.year.toString(),
      filePath: entry.filePath,
      downloadUrl: entry.downloadUrl,
      fileSize: '',
      uploadedAt: entry.uploadedAt,
      status: 'approved',
    );
    return deletePaper(meta);
  }

  static Future<String?> downloadSharedPaper(SharedPaperEntry entry) async {
    final meta = entry.toMeta();
    return downloadPaper(meta);
  }

  // ─── Keep old uploadPaper signature for existing upload_paper_screen ──

  static Future<GitHubResult> uploadPaperLegacy({
    required String facultyId,
    required String semesterId,
    required String subjectId,
    required String subjectName,
    required int year,
    required File pdfFile,
    void Function(String status)? onStatus,
  }) => uploadPaper(
    faculty: facultyId.toUpperCase(),
    year: '1st Year',
    semester: semesterId,
    subject: subjectName,
    examYear: year.toString(),
    pdfFile: pdfFile,
    onStatus: onStatus,
  );

  // ─── Utility ───────────────────────────────────────────────────────────

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────────────────

class GitHubResult {
  final bool success;
  final String message;
  final String? downloadUrl;
  final bool isDuplicate;
  final PaperMetadata? entry;

  GitHubResult({
    required this.success,
    required this.message,
    this.downloadUrl,
    this.isDuplicate = false,
    this.entry,
  });
}

// ─── Rich metadata matching the requested JSON schema ─────────────────────────
//
//  {
//    "faculty": "BCA",
//    "year": "2nd Year",
//    "semester": "Semester 3",
//    "subject": "Data Structures",
//    "exam_year": "2023",
//    "file": "2023.pdf",
//    "file_path": "SmartQPaper/BCA/2ndYear/Semester3/DataStructures/2023.pdf",
//    "download_url": "...",
//    "file_size": "1.2 MB",
//    "uploaded_at": "2026-03-06T10:00:00.000Z",
//    "status": "approved"
//  }
// ─────────────────────────────────────────────────────────────────────────────

class PaperMetadata {
  final String faculty;
  final String year;
  final String semester;
  final String subject;
  final String examYear;
  final String filePath;
  final String downloadUrl;
  final String fileSize;
  final String uploadedAt;
  final String status; // 'approved' | 'pending'

  PaperMetadata({
    required this.faculty,
    required this.year,
    required this.semester,
    required this.subject,
    required this.examYear,
    required this.filePath,
    required this.downloadUrl,
    required this.fileSize,
    required this.uploadedAt,
    this.status = 'approved',
  });

  factory PaperMetadata.fromJson(Map<String, dynamic> j) => PaperMetadata(
    faculty: j['faculty'] as String? ?? '',
    year: j['year'] as String? ?? '',
    semester: j['semester'] as String? ?? '',
    subject: j['subject'] as String? ?? '',
    examYear: (j['exam_year'] ?? j['examYear'] ?? '').toString(),
    filePath: (j['file_path'] ?? j['filePath'] ?? '').toString(),
    downloadUrl: (j['download_url'] ?? j['downloadUrl'] ?? '').toString(),
    fileSize: (j['file_size'] ?? j['fileSize'] ?? '').toString(),
    uploadedAt: (j['uploaded_at'] ?? j['uploadedAt'] ?? '').toString(),
    status: (j['status'] ?? 'approved').toString(),
  );

  Map<String, dynamic> toJson() => {
    'faculty': faculty,
    'year': year,
    'semester': semester,
    'subject': subject,
    'exam_year': examYear,
    'file': '$examYear.pdf',
    'file_path': filePath,
    'download_url': downloadUrl,
    'file_size': fileSize,
    'uploaded_at': uploadedAt,
    'status': status,
  };

  SharedPaperEntry toSharedEntry() => SharedPaperEntry(
    facultyId: faculty,
    semesterId: semester,
    subjectId: subject,
    subjectName: subject,
    year: int.tryParse(examYear) ?? 0,
    fileName: '$examYear.pdf',
    downloadUrl: downloadUrl,
    filePath: filePath,
    uploadedAt: uploadedAt,
  );
}

// ─── Legacy model (kept for SharedPapersScreen backward compat) ───────────────

class SharedPaperEntry {
  final String facultyId;
  final String semesterId;
  final String subjectId;
  final String subjectName;
  final int year;
  final String fileName;
  final String downloadUrl;
  final String filePath;
  final String uploadedAt;

  SharedPaperEntry({
    required this.facultyId,
    required this.semesterId,
    required this.subjectId,
    required this.subjectName,
    required this.year,
    required this.fileName,
    required this.downloadUrl,
    required this.filePath,
    required this.uploadedAt,
  });

  factory SharedPaperEntry.fromJson(Map<String, dynamic> j) => SharedPaperEntry(
    facultyId: j['facultyId'] as String? ?? j['faculty'] as String? ?? '',
    semesterId: j['semesterId'] as String? ?? j['semester'] as String? ?? '',
    subjectId: j['subjectId'] as String? ?? j['subject'] as String? ?? '',
    subjectName: j['subjectName'] as String? ?? j['subject'] as String? ?? '',
    year: j['year'] is int
        ? j['year'] as int
        : int.tryParse(j['exam_year']?.toString() ?? '0') ?? 0,
    fileName: j['fileName'] as String? ?? '${j['exam_year'] ?? '0'}.pdf',
    downloadUrl: (j['downloadUrl'] ?? j['download_url'] ?? '').toString(),
    filePath: (j['filePath'] ?? j['file_path'] ?? '').toString(),
    uploadedAt: (j['uploadedAt'] ?? j['uploaded_at'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'facultyId': facultyId,
    'semesterId': semesterId,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'year': year,
    'fileName': fileName,
    'downloadUrl': downloadUrl,
    'filePath': filePath,
    'uploadedAt': uploadedAt,
  };

  PaperMetadata toMeta() => PaperMetadata(
    faculty: facultyId,
    year: semesterId,
    semester: semesterId,
    subject: subjectName,
    examYear: year.toString(),
    filePath: filePath,
    downloadUrl: downloadUrl,
    fileSize: '',
    uploadedAt: uploadedAt,
  );
}
