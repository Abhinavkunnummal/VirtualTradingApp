class QuizQuestionModel {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestionModel({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? []).map((o) => o.toString()).toList(),
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class ContentSectionModel {
  final String heading;
  final String body;

  const ContentSectionModel({required this.heading, required this.body});

  factory ContentSectionModel.fromJson(Map<String, dynamic> json) {
    return ContentSectionModel(
      heading: json['heading'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class LearningModuleModel {
  final String id;
  final int order;
  final String title;
  final String category;
  final int readTimeMinutes;
  final String description;
  final List<String> learningObjectives;
  final List<ContentSectionModel> contentSections;
  final List<String> keyTakeaways;
  final List<QuizQuestionModel> quizzes;

  const LearningModuleModel({
    required this.id,
    required this.order,
    required this.title,
    required this.category,
    required this.readTimeMinutes,
    required this.description,
    required this.learningObjectives,
    required this.contentSections,
    required this.keyTakeaways,
    required this.quizzes,
  });

  factory LearningModuleModel.fromJson(Map<String, dynamic> json) {
    return LearningModuleModel(
      id: json['id'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      readTimeMinutes: (json['readTimeMinutes'] as num?)?.toInt() ?? 5,
      description: json['description'] as String? ?? '',
      learningObjectives: (json['learningObjectives'] as List<dynamic>? ?? []).map((o) => o.toString()).toList(),
      contentSections: (json['contentSections'] as List<dynamic>? ?? [])
          .map((s) => ContentSectionModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      keyTakeaways: (json['keyTakeaways'] as List<dynamic>? ?? []).map((t) => t.toString()).toList(),
      quizzes: (json['quizzes'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TutorResponseModel {
  final String question;
  final String answer;
  final String exampleScenario;
  final String actionableTip;
  final String disclaimer;

  const TutorResponseModel({
    required this.question,
    required this.answer,
    required this.exampleScenario,
    required this.actionableTip,
    required this.disclaimer,
  });

  factory TutorResponseModel.fromJson(Map<String, dynamic> json) {
    return TutorResponseModel(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      exampleScenario: json['exampleScenario'] as String? ?? '',
      actionableTip: json['actionableTip'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
