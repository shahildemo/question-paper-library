import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/faculty_model.dart';
import '../models/subject_model.dart';

class DataService {
  static List<Faculty>? _cachedFaculties;

  static Future<List<Faculty>> loadFaculties() async {
    if (_cachedFaculties != null) {
      return _cachedFaculties!;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/papers_data.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> facultiesJson = jsonData['faculties'] as List<dynamic>;
      
      _cachedFaculties = facultiesJson
          .map((faculty) => Faculty.fromJson(faculty as Map<String, dynamic>))
          .toList();
      
      return _cachedFaculties!;
    } catch (e) {
      throw Exception('Failed to load faculties: $e');
    }
  }

  static Future<Faculty?> getFacultyById(String id) async {
    final faculties = await loadFaculties();
    try {
      return faculties.firstWhere((faculty) => faculty.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<List<Subject>> searchSubjects(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final faculties = await loadFaculties();
    final List<Subject> results = [];
    final searchLower = query.toLowerCase();

    for (final faculty in faculties) {
      for (final year in faculty.years) {
        for (final semester in year.semesters) {
          for (final subject in semester.subjects) {
            if (subject.name.toLowerCase().contains(searchLower) ||
                subject.code.toLowerCase().contains(searchLower)) {
              results.add(subject);
            }
          }
        }
      }
    }

    return results;
  }

  static Future<Subject?> getSubjectById(String id) async {
    final faculties = await loadFaculties();
    
    for (final faculty in faculties) {
      for (final year in faculty.years) {
        for (final semester in year.semesters) {
          try {
            return semester.subjects.firstWhere((subject) => subject.id == id);
          } catch (e) {
            continue;
          }
        }
      }
    }
    return null;
  }

  static void clearCache() {
    _cachedFaculties = null;
  }
}
