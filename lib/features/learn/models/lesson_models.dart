class LessonCourse {
  final String id;
  final String title;
  final String? description;
  final bool isPublic;
  final String? imageUrl;
  final String? creatorId;

  LessonCourse({
    required this.id,
    required this.title,
    this.description,
    this.isPublic = false,
    this.imageUrl,
    this.creatorId,
  });

  factory LessonCourse.fromJson(Map<String, dynamic> json) {
    return LessonCourse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
      creatorId: json['creator_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_public': isPublic,
      'image_url': imageUrl,
      'creator_id': creatorId,
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
  final List<LessonBlock>? blocks;

  LessonPage({
    required this.id,
    required this.subChapterId,
    required this.position,
    this.blocks,
  });

  factory LessonPage.fromJson(Map<String, dynamic> json) {
    List<LessonBlock>? loadedBlocks;
    if (json['lesson_blocks'] != null) {
      final list = json['lesson_blocks'] as List;
      loadedBlocks = list.map((e) => LessonBlock.fromJson(e)).toList();
      loadedBlocks.sort((a, b) => a.position.compareTo(b.position));
    }
    return LessonPage(
      id: json['id'] as String,
      subChapterId: json['sub_chapter_id'] as String,
      position: json['position'] as int? ?? 0,
      blocks: loadedBlocks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_chapter_id': subChapterId,
      'position': position,
      if (blocks != null) 'lesson_blocks': blocks!.map((b) => b.toJson()).toList(),
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
