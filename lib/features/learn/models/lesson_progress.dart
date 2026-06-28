import 'package:supabase_flutter/supabase_flutter.dart';

class LessonProgress {
  static final LessonProgress _instance = LessonProgress._internal();
  factory LessonProgress() => _instance;
  LessonProgress._internal();

  final Set<String> completedSubChapters = {};
  final Map<String, int> subChapterSlideProgress = {};

  bool isCompleted(String id) => completedSubChapters.contains(id);

  int getSavedSlideIndex(String id) => subChapterSlideProgress[id] ?? 0;

  Future<void> complete(String id) async {
    completedSubChapters.add(id);
    subChapterSlideProgress.remove(id); // Clear slide index since completed
    await _saveToSupabase();
  }

  Future<void> saveSlideIndex(String id, int index) async {
    final current = subChapterSlideProgress[id] ?? 0;
    if (index > current) {
      subChapterSlideProgress[id] = index;
      await _saveToSupabase();
    }
  }

  Future<void> clearSlideIndex(String id) async {
    if (subChapterSlideProgress.containsKey(id)) {
      subChapterSlideProgress.remove(id);
      await _saveToSupabase();
    }
  }

  void clear() {
    completedSubChapters.clear();
    subChapterSlideProgress.clear();
  }

  Future<void> loadFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metadata = user.userMetadata;
        
        // Load completed sub chapters
        if (metadata != null && metadata.containsKey('completed_sub_chapters')) {
          final list = metadata['completed_sub_chapters'];
          if (list is List) {
            completedSubChapters.clear();
            completedSubChapters.addAll(list.map((e) => e.toString()));
          }
        }

        // Load slide progress
        if (metadata != null && metadata.containsKey('lesson_slide_progress')) {
          final progressMap = metadata['lesson_slide_progress'];
          if (progressMap is Map) {
            subChapterSlideProgress.clear();
            progressMap.forEach((key, value) {
              if (value is int) {
                subChapterSlideProgress[key.toString()] = value;
              } else if (value is String) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  subChapterSlideProgress[key.toString()] = parsed;
                }
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToSupabase() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'completed_sub_chapters': completedSubChapters.toList(),
              'lesson_slide_progress': subChapterSlideProgress,
            },
          ),
        );
      }
    } catch (_) {}
  }
}
