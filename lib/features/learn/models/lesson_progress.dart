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
    
    int currentXp = 0;
    int currentWeeklyXp = 0;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      if (metadata != null && metadata.containsKey('xp')) {
        currentXp = int.tryParse(metadata['xp'].toString()) ?? 0;
      }
      if (metadata != null && metadata.containsKey('weekly_xp')) {
        currentWeeklyXp = int.tryParse(metadata['weekly_xp'].toString()) ?? 0;
      }
    }
    final nextXp = currentXp + 10;
    final nextWeeklyXp = currentWeeklyXp + 10;
    await _saveToSupabase(nextXp, nextWeeklyXp);
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

  Future<void> _saveToSupabase([int? nextXp, int? nextWeeklyXp]) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        int currentXp = 0;
        int currentWeeklyXp = 0;
        final metadata = user.userMetadata;
        if (metadata != null && metadata.containsKey('xp')) {
          currentXp = int.tryParse(metadata['xp'].toString()) ?? 0;
        }
        if (metadata != null && metadata.containsKey('weekly_xp')) {
          currentWeeklyXp = int.tryParse(metadata['weekly_xp'].toString()) ?? 0;
        }
        final xpToSave = nextXp ?? currentXp;
        final weeklyXpToSave = nextWeeklyXp ?? currentWeeklyXp;

        await client.auth.updateUser(
          UserAttributes(
            data: {
              'completed_sub_chapters': completedSubChapters.toList(),
              'lesson_slide_progress': subChapterSlideProgress,
              'xp': xpToSave,
              'weekly_xp': weeklyXpToSave,
            },
          ),
        );

        // Also update profiles directly in public schema
        await client.from('profiles').update({
          'xp': xpToSave,
          'weekly_xp': weeklyXpToSave,
        }).eq('id', user.id);
      }
    } catch (_) {}
  }
}
