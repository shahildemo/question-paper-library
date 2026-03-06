import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/paper_model.dart';
import '../models/subject_model.dart';

class PaperManagementService {
  static const String _customPapersKey = 'custom_papers';
  static const String _customSubjectsKey = 'custom_subjects';
  static const String _deletedPapersKey = 'deleted_papers';
  
  static Directory? _appDirectory;

  static Future<void> init() async {
    _appDirectory = await getApplicationDocumentsDirectory();
    final papersDir = Directory('${_appDirectory!.path}/custom_papers');
    if (!await papersDir.exists()) {
      await papersDir.create(recursive: true);
    }
  }

  static Future<String> getPapersDirectory() async {
    if (_appDirectory == null) {
      await init();
    }
    return '${_appDirectory!.path}/custom_papers';
  }

  // Get list of deleted paper IDs
  static Future<Set<String>> getDeletedPaperIds() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedList = prefs.getStringList(_deletedPapersKey) ?? [];
    return deletedList.toSet();
  }

  // Mark a paper as deleted
  static Future<void> markPaperAsDeleted(String paperId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedSet = await getDeletedPaperIds();
    deletedSet.add(paperId);
    await prefs.setStringList(_deletedPapersKey, deletedSet.toList());
  }

  // Restore a deleted paper
  static Future<void> restorePaper(String paperId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedSet = await getDeletedPaperIds();
    deletedSet.remove(paperId);
    await prefs.setStringList(_deletedPapersKey, deletedSet.toList());
  }

  // Save uploaded paper
  static Future<Paper?> uploadPaper({
    required String subjectId,
    required int year,
    required File pdfFile,
  }) async {
    try {
      final papersDir = await getPapersDirectory();
      final paperId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = '${subjectId}_${year}_$paperId.pdf';
      final savedPath = '$papersDir/$fileName';
      
      // Copy file to app directory
      await pdfFile.copy(savedPath);
      
      final fileStats = await pdfFile.length();
      final fileSize = _formatFileSize(fileStats);
      
      final paper = Paper(
        id: paperId,
        year: year,
        subjectId: subjectId,
        fileName: fileName,
        filePath: savedPath,
        fileSize: fileSize,
      );
      
      // Save to custom papers list
      await _saveCustomPaper(paper);
      
      return paper;
    } catch (e) {
      debugPrint('Error uploading paper: $e');
      return null;
    }
  }

  // Delete a custom paper
  static Future<bool> deletePaper(Paper paper) async {
    try {
      // If it's a custom paper, delete the file
      if (paper.id.startsWith('custom_')) {
        final file = File(paper.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        await _removeCustomPaper(paper.id);
      } else {
        // For default papers, just mark as deleted
        await markPaperAsDeleted(paper.id);
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting paper: $e');
      return false;
    }
  }

  // Get all custom papers
  static Future<List<Paper>> getCustomPapers() async {
    final prefs = await SharedPreferences.getInstance();
    final papersJson = prefs.getString(_customPapersKey);
    
    if (papersJson == null) return [];
    
    final List<dynamic> papersList = json.decode(papersJson);
    return papersList
        .map((json) => Paper.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Get custom papers for a specific subject
  static Future<List<Paper>> getCustomPapersForSubject(String subjectId) async {
    final allPapers = await getCustomPapers();
    return allPapers.where((p) => p.subjectId == subjectId).toList();
  }

  // Save custom paper
  static Future<void> _saveCustomPaper(Paper paper) async {
    final prefs = await SharedPreferences.getInstance();
    final papers = await getCustomPapers();
    papers.add(paper);
    
    final papersJson = json.encode(papers.map((p) => p.toJson()).toList());
    await prefs.setString(_customPapersKey, papersJson);
  }

  // Remove custom paper from list
  static Future<void> _removeCustomPaper(String paperId) async {
    final prefs = await SharedPreferences.getInstance();
    final papers = await getCustomPapers();
    papers.removeWhere((p) => p.id == paperId);
    
    final papersJson = json.encode(papers.map((p) => p.toJson()).toList());
    await prefs.setString(_customPapersKey, papersJson);
  }

  // Create custom subject
  static Future<Subject?> createCustomSubject({
    required String semesterId,
    required String name,
    required String code,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subjectId = 'custom_subject_${DateTime.now().millisecondsSinceEpoch}';
      
      final subject = Subject(
        id: subjectId,
        name: name,
        code: code,
        semesterId: semesterId,
        papers: [],
      );
      
      final subjects = await getCustomSubjects();
      subjects.add(subject);
      
      final subjectsJson = json.encode(subjects.map((s) => s.toJson()).toList());
      await prefs.setString(_customSubjectsKey, subjectsJson);
      
      return subject;
    } catch (e) {
      debugPrint('Error creating subject: $e');
      return null;
    }
  }

  // Get custom subjects
  static Future<List<Subject>> getCustomSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final subjectsJson = prefs.getString(_customSubjectsKey);
    
    if (subjectsJson == null) return [];
    
    final List<dynamic> subjectsList = json.decode(subjectsJson);
    return subjectsList
        .map((json) => Subject.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Get custom subjects for a specific semester
  static Future<List<Subject>> getCustomSubjectsForSemester(String semesterId) async {
    final allSubjects = await getCustomSubjects();
    return allSubjects.where((s) => s.semesterId == semesterId).toList();
  }

  // Delete custom subject
  static Future<bool> deleteSubject(String subjectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Delete all papers in this subject
      final papers = await getCustomPapers();
      final subjectPapers = papers.where((p) => p.subjectId == subjectId).toList();
      
      for (final paper in subjectPapers) {
        final file = File(paper.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Remove papers and subject from storage
      final remainingPapers = papers.where((p) => p.subjectId != subjectId).toList();
      final papersJson = json.encode(remainingPapers.map((p) => p.toJson()).toList());
      await prefs.setString(_customPapersKey, papersJson);
      
      final subjects = await getCustomSubjects();
      subjects.removeWhere((s) => s.id == subjectId);
      final subjectsJson = json.encode(subjects.map((s) => s.toJson()).toList());
      await prefs.setString(_customSubjectsKey, subjectsJson);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting subject: $e');
      return false;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
