import 'subject_model.dart';

class Semester {
  final String id;
  final String name;
  final String yearId;
  final List<Subject> subjects;

  Semester({
    required this.id,
    required this.name,
    required this.yearId,
    required this.subjects,
  });

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'] as String,
      name: json['name'] as String,
      yearId: json['yearId'] as String,
      subjects: (json['subjects'] as List<dynamic>)
          .map((subject) => Subject.fromJson(subject as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'yearId': yearId,
      'subjects': subjects.map((subject) => subject.toJson()).toList(),
    };
  }
}
