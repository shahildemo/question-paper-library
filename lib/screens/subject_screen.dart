import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_strings.dart';
import '../providers/navigation_provider.dart';
import '../widgets/subject_card.dart';
import '../widgets/search_bar_widget.dart';
import 'paper_screen.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredSubjects = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSubjects(String query, List<dynamic> subjects) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredSubjects = subjects;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredSubjects = subjects.where((subject) {
          return subject.name.toLowerCase().contains(lowerQuery) ||
              subject.code.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigation, child) {
        final faculty = navigation.selectedFaculty;
        final year = navigation.selectedYear;
        final semester = navigation.selectedSemester;

        if (faculty == null || year == null || semester == null) {
          return const Scaffold(
            body: Center(
              child: Text('No semester selected'),
            ),
          );
        }

        final subjects = semester.subjects;
        final displaySubjects = _isSearching ? _filteredSubjects : subjects;

        return Scaffold(
          appBar: AppBar(
            title: Text('${semester.name} - ${AppStrings.selectSubject}'),
          ),
          body: Column(
            children: [
              SearchBarWidget(
                controller: _searchController,
                onChanged: (query) => _filterSubjects(query, subjects),
                onClear: () {
                  setState(() {
                    _isSearching = false;
                    _filteredSubjects = [];
                  });
                },
              ),
              Expanded(
                child: displaySubjects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isSearching
                                  ? AppStrings.noSubjectsFound
                                  : 'No subjects available',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displaySubjects.length,
                        itemBuilder: (context, index) {
                          final subject = displaySubjects[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SubjectCard(
                              subject: subject,
                              onTap: () {
                                navigation.selectSubject(subject);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PaperScreen(),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
