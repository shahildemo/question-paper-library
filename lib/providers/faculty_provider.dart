import 'package:flutter/foundation.dart';
import '../models/faculty_model.dart';
import '../models/subject_model.dart';
import '../services/data_service.dart';

class FacultyProvider extends ChangeNotifier {
  List<Faculty> _faculties = [];
  bool _isLoading = false;
  String? _error;
  List<Subject> _searchResults = [];
  bool _isSearching = false;

  List<Faculty> get faculties => _faculties;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Subject> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  Future<void> loadFaculties() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _faculties = await DataService.loadFaculties();
      _error = null;
    } catch (e) {
      _error = 'Failed to load faculties: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSubjects(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await DataService.searchSubjects(query);
    } catch (e) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  Future<Subject?> getSubjectById(String id) async {
    return await DataService.getSubjectById(id);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
