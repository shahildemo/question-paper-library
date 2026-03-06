import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_strings.dart';
import '../providers/navigation_provider.dart';
import '../widgets/year_card.dart';
import 'semester_screen.dart';

class YearScreen extends StatelessWidget {
  const YearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigation, child) {
        final faculty = navigation.selectedFaculty;

        if (faculty == null) {
          return const Scaffold(
            body: Center(
              child: Text('No faculty selected'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${faculty.name} - ${AppStrings.selectYear}'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: faculty.years.length,
              itemBuilder: (context, index) {
                final year = faculty.years[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: YearCard(
                    year: year,
                    onTap: () {
                      navigation.selectYear(year);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SemesterScreen(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
