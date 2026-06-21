class LessonCourse {
  final String id;
  final String title;

  LessonCourse({
    required this.id,
    required this.title,
  });

  factory LessonCourse.fromJson(Map<String, dynamic> json) {
    return LessonCourse(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }
}

class LessonChapter {
  final String id;
  final String? courseId;
  final String title;
  final int position;

  LessonChapter({
    required this.id,
    this.courseId,
    required this.title,
    required this.position,
  });

  factory LessonChapter.fromJson(Map<String, dynamic> json) {
    return LessonChapter(
      id: json['id'] as String,
      courseId: json['course_id'] as String?,
      title: json['title'] as String,
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'position': position,
    };
  }
}

class LessonSubChapter {
  final String id;
  final String chapterId;
  final String title;
  final int xpReward;
  final int position;

  LessonSubChapter({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.xpReward,
    required this.position,
  });

  factory LessonSubChapter.fromJson(Map<String, dynamic> json) {
    return LessonSubChapter(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      xpReward: json['xp_reward'] as int? ?? 10,
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'title': title,
      'xp_reward': xpReward,
      'position': position,
    };
  }
}

class LessonPage {
  final String id;
  final String subChapterId;
  final int position;

  LessonPage({
    required this.id,
    required this.subChapterId,
    required this.position,
  });

  factory LessonPage.fromJson(Map<String, dynamic> json) {
    return LessonPage(
      id: json['id'] as String,
      subChapterId: json['sub_chapter_id'] as String,
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_chapter_id': subChapterId,
      'position': position,
    };
  }
}

class LessonBlock {
  final String id;
  final String pageId;
  final String blockType; // 'text', 'media', 'test', 'file'
  final Map<String, dynamic> content;
  final int position;

  LessonBlock({
    required this.id,
    required this.pageId,
    required this.blockType,
    required this.content,
    required this.position,
  });

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    return LessonBlock(
      id: json['id'] as String,
      pageId: json['page_id'] as String,
      blockType: json['block_type'] as String,
      content: json['content'] as Map<String, dynamic>? ?? {},
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'page_id': pageId,
      'block_type': blockType,
      'content': content,
      'position': position,
    };
  }
}
