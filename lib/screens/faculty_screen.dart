import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_strings.dart';
import '../providers/faculty_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/faculty_card.dart';
import 'year_screen.dart';

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FacultyProvider>().loadFaculties();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.selectFaculty),
      ),
      body: Consumer<FacultyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadFaculties(),
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            );
          }

          if (provider.faculties.isEmpty) {
            return const Center(
              child: Text('No faculties available'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: provider.faculties.length,
              itemBuilder: (context, index) {
                final faculty = provider.faculties[index];
                return FacultyCard(
                  faculty: faculty,
                  onTap: () {
                    context.read<NavigationProvider>().selectFaculty(faculty);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const YearScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
