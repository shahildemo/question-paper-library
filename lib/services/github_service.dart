import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GitHubService {
  static const String _baseUrl = 'https://api.github.com';
  static const String _tokenKey = 'github_token';
  static const String _repoOwnerKey = 'github_repo_owner';
  static const String _repoNameKey = 'github_repo_name';
  static const String _branchKey = 'github_branch';
  static const String _papersFolder = 'shared_papers';

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
    final config = await getConfig();
    return config['token'] != null &&
        config['repoOwner'] != null &&
        config['repoName'] != null;
  }

  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_repoOwnerKey);
    await prefs.remove(_repoNameKey);
    await prefs.remove(_branchKey);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  static Map<String, String> _headers(String token) => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      };

  /// Build the GitHub content API path for a paper
  static String _filePath(String facultyId, String semesterId,
          String subjectId, int year, String fileName) =>
      '$_papersFolder/$facultyId/$semesterId/$subjectId/${year}_$fileName';

  // ─── Validate Token ───────────────────────────────────────────────────

  static Future<GitHubResult> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GitHubResult(
            success: true, message: 'Connected as ${data['login']}');
      }
      return GitHubResult(
          success: false, message: 'Invalid token (${response.statusCode})');
    } catch (e) {
      return GitHubResult(success: false, message: 'Network error: $e');
    }
  }

  // ─── Upload Paper ─────────────────────────────────────────────────────

  static Future<GitHubResult> uploadPaper({
    required String facultyId,
    required String semesterId,
    required String subjectId,
    required String subjectName,
    required int year,
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
            success: false, message: 'GitHub not configured. Go to Settings.');
      }

      onStatus?.call('Encoding file…');
      final bytes = await pdfFile.readAsBytes();
      final base64Content = base64Encode(bytes);
      final fileName = pdfFile.path.split('/').last;
      final filePath = _filePath(facultyId, semesterId, subjectId, year, fileName);
      final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$filePath';

      // Check if file already exists (need its SHA for update)
      String? existingSha;
      final checkResp = await http.get(
        Uri.parse(apiUrl),
        headers: _headers(token),
      );
      if (checkResp.statusCode == 200) {
        existingSha = json.decode(checkResp.body)['sha'] as String?;
      }

      onStatus?.call('Uploading to GitHub…');
      final body = json.encode({
        'message': 'Upload $subjectName $year paper',
        'content': base64Content,
        'branch': branch,
        if (existingSha != null) 'sha': existingSha,
      });

      final uploadResp = await http.put(
        Uri.parse(apiUrl),
        headers: _headers(token),
        body: body,
      );

      if (uploadResp.statusCode == 200 || uploadResp.statusCode == 201) {
        final respData = json.decode(uploadResp.body);
        final downloadUrl = respData['content']['download_url'] as String;

        onStatus?.call('Updating index…');
        await _updateIndex(
          token: token,
          owner: owner,
          repo: repo,
          branch: branch,
          entry: SharedPaperEntry(
            facultyId: facultyId,
            semesterId: semesterId,
            subjectId: subjectId,
            subjectName: subjectName,
            year: year,
            fileName: fileName,
            downloadUrl: downloadUrl,
            filePath: filePath,
            uploadedAt: DateTime.now().toIso8601String(),
          ),
        );

        return GitHubResult(
          success: true,
          message: 'Paper uploaded successfully! All users can now access it.',
          downloadUrl: downloadUrl,
        );
      }

      return GitHubResult(
        success: false,
        message: 'Upload failed (${uploadResp.statusCode}): ${uploadResp.body}',
      );
    } catch (e) {
      return GitHubResult(success: false, message: 'Upload error: $e');
    }
  }

  // ─── Index file ───────────────────────────────────────────────────────

  static const String _indexPath = '$_papersFolder/index.json';

  static Future<void> _updateIndex({
    required String token,
    required String owner,
    required String repo,
    required String branch,
    required SharedPaperEntry entry,
  }) async {
    final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$_indexPath';

    // Fetch existing index
    List<dynamic> existing = [];
    String? existingSha;

    final getResp = await http.get(
      Uri.parse(apiUrl),
      headers: _headers(token),
    );
    if (getResp.statusCode == 200) {
      final data = json.decode(getResp.body);
      existingSha = data['sha'] as String?;
      final decoded = utf8.decode(base64Decode(data['content'].toString().replaceAll('\n', '')));
      existing = json.decode(decoded) as List<dynamic>;
    }

    // Add new entry (remove duplicate if exists)
    existing.removeWhere((e) =>
        e['subjectId'] == entry.subjectId &&
        e['year'] == entry.year &&
        e['fileName'] == entry.fileName);
    existing.add(entry.toJson());

    final newContent = base64Encode(utf8.encode(json.encode(existing)));
    final body = json.encode({
      'message': 'Update papers index',
      'content': newContent,
      'branch': branch,
      if (existingSha != null) 'sha': existingSha,
    });

    await http.put(
      Uri.parse(apiUrl),
      headers: _headers(token),
      body: body,
    );
  }

  // ─── Fetch Shared Papers ──────────────────────────────────────────────

  static Future<List<SharedPaperEntry>> fetchSharedPapers({
    String? subjectId,
  }) async {
    try {
      final config = await getConfig();
      final token = config['token'];
      final owner = config['repoOwner'];
      final repo = config['repoName'];

      if (token == null || owner == null || repo == null) return [];

      final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$_indexPath';
      final resp = await http.get(
        Uri.parse(apiUrl),
        headers: _headers(token),
      );

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final decoded = utf8.decode(
          base64Decode(data['content'].toString().replaceAll('\n', '')));
      final List<dynamic> list = json.decode(decoded);

      final entries = list
          .map((e) => SharedPaperEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      if (subjectId != null) {
        return entries.where((e) => e.subjectId == subjectId).toList();
      }
      return entries;
    } catch (e) {
      return [];
    }
  }

  // ─── Delete Shared Paper ──────────────────────────────────────────────

  static Future<GitHubResult> deleteSharedPaper(SharedPaperEntry entry) async {
    try {
      final config = await getConfig();
      final token = config['token'];
      final owner = config['repoOwner'];
      final repo = config['repoName'];
      final branch = config['branch'] ?? 'main';

      if (token == null || owner == null || repo == null) {
        return GitHubResult(success: false, message: 'GitHub not configured.');
      }

      final apiUrl =
          '$_baseUrl/repos/$owner/$repo/contents/${entry.filePath}';

      // Get file SHA
      final getResp =
          await http.get(Uri.parse(apiUrl), headers: _headers(token));
      if (getResp.statusCode != 200) {
        return GitHubResult(success: false, message: 'File not found on GitHub.');
      }
      final sha = json.decode(getResp.body)['sha'] as String;

      // Delete file
      final body = json.encode({
        'message': 'Delete ${entry.subjectName} ${entry.year} paper',
        'sha': sha,
        'branch': branch,
      });

      final delResp = await http.delete(
        Uri.parse(apiUrl),
        headers: _headers(token),
        body: body,
      );

      if (delResp.statusCode == 200) {
        // Remove from index
        await _removeFromIndex(
            token: token,
            owner: owner,
            repo: repo,
            branch: branch,
            entry: entry);
        return GitHubResult(
            success: true, message: 'Paper deleted from shared library.');
      }

      return GitHubResult(
          success: false,
          message: 'Delete failed (${delResp.statusCode})');
    } catch (e) {
      return GitHubResult(success: false, message: 'Error: $e');
    }
  }

  static Future<void> _removeFromIndex({
    required String token,
    required String owner,
    required String repo,
    required String branch,
    required SharedPaperEntry entry,
  }) async {
    final apiUrl = '$_baseUrl/repos/$owner/$repo/contents/$_indexPath';
    final getResp =
        await http.get(Uri.parse(apiUrl), headers: _headers(token));
    if (getResp.statusCode != 200) return;

    final data = json.decode(getResp.body);
    final existingSha = data['sha'] as String;
    final decoded = utf8.decode(
        base64Decode(data['content'].toString().replaceAll('\n', '')));
    final List<dynamic> existing = json.decode(decoded);

    existing.removeWhere((e) =>
        e['subjectId'] == entry.subjectId &&
        e['year'] == entry.year &&
        e['fileName'] == entry.fileName);

    final newContent = base64Encode(utf8.encode(json.encode(existing)));
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

  // ─── Download shared paper to local cache ────────────────────────────

  static Future<String?> downloadSharedPaper(SharedPaperEntry entry) async {
    try {
      final response = await http.get(Uri.parse(entry.downloadUrl));
      if (response.statusCode != 200) return null;

      final config = await getConfig();
      final token = config['token']!;
      final owner = config['repoOwner']!;
      final repo = config['repoName']!;

      // Use raw content URL for actual binary download
      final rawUrl =
          'https://raw.githubusercontent.com/$owner/$repo/main/${entry.filePath}';
      final rawResp = await http.get(
        Uri.parse(rawUrl),
        headers: _headers(token),
      );
      if (rawResp.statusCode != 200) return null;

      final tempDir = Directory.systemTemp;
      final cacheDir = Directory('${tempDir.path}/qpl_cache');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final file = File('${cacheDir.path}/${entry.year}_${entry.fileName}');
      await file.writeAsBytes(rawResp.bodyBytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

class GitHubResult {
  final bool success;
  final String message;
  final String? downloadUrl;

  GitHubResult({
    required this.success,
    required this.message,
    this.downloadUrl,
  });
}

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

  factory SharedPaperEntry.fromJson(Map<String, dynamic> json) =>
      SharedPaperEntry(
        facultyId: json['facultyId'] as String,
        semesterId: json['semesterId'] as String,
        subjectId: json['subjectId'] as String,
        subjectName: json['subjectName'] as String,
        year: json['year'] as int,
        fileName: json['fileName'] as String,
        downloadUrl: json['downloadUrl'] as String,
        filePath: json['filePath'] as String,
        uploadedAt: json['uploadedAt'] as String,
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
}
