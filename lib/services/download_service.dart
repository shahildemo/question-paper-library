import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class DownloadService {
  static final Dio _dio = Dio();

  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need different permissions
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      // Try requesting manage external storage for Android 11+
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }
    return true;
  }

  static Future<String> getDownloadPath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/QuestionPapers');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/QuestionPapers');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir.path;
    }

    return directory.path;
  }

  static Future<String?> copyAssetToTemp(
    String assetPath,
    String fileName,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file.path;
    } catch (e) {
      return null;
    }
  }

  static Future<DownloadResult> downloadFile({
    required String sourcePath,
    required String fileName,
    required bool isAsset,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        return DownloadResult(
          success: false,
          message: 'Storage permission denied',
          filePath: null,
        );
      }

      final downloadPath = await getDownloadPath();
      final filePath = path.join(downloadPath, fileName);

      // Check if file already exists
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        return DownloadResult(
          success: true,
          message: 'File already downloaded',
          filePath: filePath,
        );
      }

      if (isAsset) {
        // Copy from assets
        final byteData = await rootBundle.load(sourcePath);
        await existingFile.writeAsBytes(byteData.buffer.asUint8List());
      } else {
        // Check if sourcePath is a local file or URL
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          // Copy from local file
          await sourceFile.copy(filePath);
        } else {
          // Download from URL
          await _dio.download(
            sourcePath,
            filePath,
            onReceiveProgress: onProgress,
          );
        }
      }

      return DownloadResult(
        success: true,
        message: 'Download complete',
        filePath: filePath,
      );
    } catch (e) {
      return DownloadResult(
        success: false,
        message: 'Download failed: $e',
        filePath: null,
      );
    }
  }

  static Future<void> openFile(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Could not open file: ${result.message}');
    }
  }

  static Future<bool> isFileDownloaded(String fileName) async {
    try {
      final downloadPath = await getDownloadPath();
      final filePath = path.join(downloadPath, fileName);
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getDownloadedFilePath(String fileName) async {
    try {
      final downloadPath = await getDownloadPath();
      final filePath = path.join(downloadPath, fileName);
      if (await File(filePath).exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class DownloadResult {
  final bool success;
  final String message;
  final String? filePath;

  DownloadResult({required this.success, required this.message, this.filePath});
}
