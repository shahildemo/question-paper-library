import 'year_model.dart';

class Faculty {
  final String id;
  final String name;
  final String code;
  final String icon;
  final List<Year> years;

  Faculty({
    required this.id,
    required this.name,
    required this.code,
    required this.icon,
    required this.years,
  });

  factory Faculty.fromJson(Map<String, dynamic> json) {
    return Faculty(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      icon: json['icon'] as String,
      years: (json['years'] as List<dynamic>)
          .map((year) => Year.fromJson(year as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'icon': icon,
      'years': years.map((year) => year.toJson()).toList(),
    };
  }
}
