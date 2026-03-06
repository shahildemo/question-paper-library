class Paper {
  final String id;
  final int year;
  final String subjectId;
  final String fileName;
  final String filePath;
  final String fileSize;

  Paper({
    required this.id,
    required this.year,
    required this.subjectId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
  });

  factory Paper.fromJson(Map<String, dynamic> json) {
    return Paper(
      id: json['id'] as String,
      year: json['year'] as int,
      subjectId: json['subjectId'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year': year,
      'subjectId': subjectId,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
    };
  }
}
