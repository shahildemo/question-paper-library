import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_strings.dart';
import '../providers/navigation_provider.dart';
import '../widgets/semester_card.dart';
import 'subject_screen.dart';

class SemesterScreen extends StatelessWidget {
  const SemesterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigation, child) {
        final faculty = navigation.selectedFaculty;
        final year = navigation.selectedYear;

        if (faculty == null || year == null) {
          return const Scaffold(
            body: Center(
              child: Text('No year selected'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${year.name} - ${AppStrings.selectSemester}'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: year.semesters.length,
              itemBuilder: (context, index) {
                final semester = year.semesters[index];
                return SemesterCard(
                  semester: semester,
                  onTap: () {
                    navigation.selectSemester(semester);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubjectScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
