import 'paper_model.dart';

class Subject {
  final String id;
  final String name;
  final String code;
  final String semesterId;
  final List<Paper> papers;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.semesterId,
    required this.papers,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      semesterId: json['semesterId'] as String,
      papers: (json['papers'] as List<dynamic>)
          .map((paper) => Paper.fromJson(paper as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'semesterId': semesterId,
      'papers': papers.map((paper) => paper.toJson()).toList(),
    };
  }
}
