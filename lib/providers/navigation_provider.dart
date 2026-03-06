import 'package:flutter/foundation.dart';
import '../models/faculty_model.dart';
import '../models/year_model.dart';
import '../models/semester_model.dart';
import '../models/subject_model.dart';

class NavigationProvider extends ChangeNotifier {
  Faculty? _selectedFaculty;
  Year? _selectedYear;
  Semester? _selectedSemester;
  Subject? _selectedSubject;

  Faculty? get selectedFaculty => _selectedFaculty;
  Year? get selectedYear => _selectedYear;
  Semester? get selectedSemester => _selectedSemester;
  Subject? get selectedSubject => _selectedSubject;

  void selectFaculty(Faculty faculty) {
    _selectedFaculty = faculty;
    _selectedYear = null;
    _selectedSemester = null;
    _selectedSubject = null;
    notifyListeners();
  }

  void selectYear(Year year) {
    _selectedYear = year;
    _selectedSemester = null;
    _selectedSubject = null;
    notifyListeners();
  }

  void selectSemester(Semester semester) {
    _selectedSemester = semester;
    _selectedSubject = null;
    notifyListeners();
  }

  void selectSubject(Subject subject) {
    _selectedSubject = subject;
    notifyListeners();
  }

  void clearSelection() {
    _selectedFaculty = null;
    _selectedYear = null;
    _selectedSemester = null;
    _selectedSubject = null;
    notifyListeners();
  }

  void goBackToFaculties() {
    _selectedFaculty = null;
    _selectedYear = null;
    _selectedSemester = null;
    _selectedSubject = null;
    notifyListeners();
  }

  void goBackToYears() {
    _selectedYear = null;
    _selectedSemester = null;
    _selectedSubject = null;
    notifyListeners();
  }

  void goBackToSemesters() {
    _selectedSemester = null;
    _selectedSubject = null;
    notifyListeners();
  }

  void goBackToSubjects() {
    _selectedSubject = null;
    notifyListeners();
  }
}
