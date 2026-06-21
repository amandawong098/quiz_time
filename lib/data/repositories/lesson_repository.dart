import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/learn/models/lesson_models.dart';

class LessonRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------
  // COURSES
  // ------------------------------------------
  Future<List<LessonCourse>> getCourses() async {
    final response = await _supabase
        .from('lesson_courses')
        .select()
        .order('created_at', ascending: true);
    return (response as List).map((e) => LessonCourse.fromJson(e)).toList();
  }

  Future<LessonCourse> createCourse(String title) async {
    final response = await _supabase
        .from('lesson_courses')
        .insert({'title': title})
        .select()
        .single();
    return LessonCourse.fromJson(response);
  }

  Future<void> updateCourse(String id, String title) async {
    await _supabase
        .from('lesson_courses')
        .update({'title': title})
        .eq('id', id);
  }

  Future<void> deleteCourse(String id) async {
    await _supabase.from('lesson_courses').delete().eq('id', id);
  }

  // ------------------------------------------
  // CHAPTERS
  // ------------------------------------------
  Future<List<LessonChapter>> getChapters([String? courseId]) async {
    var query = _supabase.from('lesson_chapters').select();
    if (courseId != null) {
      query = query.eq('course_id', courseId);
    } else {
      query = query.isFilter('course_id', null);
    }
    final response = await query.order('position', ascending: true);
    return (response as List).map((e) => LessonChapter.fromJson(e)).toList();
  }

  Future<LessonChapter> createChapter({
    required String title,
    required int position,
    String? courseId,
  }) async {
    final response = await _supabase
        .from('lesson_chapters')
        .insert({
          'title': title,
          'position': position,
          'course_id': courseId,
        })
        .select()
        .single();
    return LessonChapter.fromJson(response);
  }

  Future<void> updateChapter(String id, String title, int position, [String? courseId]) async {
    await _supabase.from('lesson_chapters').update({
      'title': title,
      'position': position,
      'course_id': courseId,
    }).eq('id', id);
  }

  Future<void> deleteChapter(String id) async {
    await _supabase.from('lesson_chapters').delete().eq('id', id);
  }

  // ------------------------------------------
  // SUB-CHAPTERS
  // ------------------------------------------
  Future<List<LessonSubChapter>> getSubChapters(String chapterId) async {
    final response = await _supabase
        .from('lesson_sub_chapters')
        .select()
        .eq('chapter_id', chapterId)
        .order('position', ascending: true);
    return (response as List).map((e) => LessonSubChapter.fromJson(e)).toList();
  }

  Future<LessonSubChapter> createSubChapter({
    required String chapterId,
    required String title,
    required int position,
    int xpReward = 10,
  }) async {
    final response = await _supabase
        .from('lesson_sub_chapters')
        .insert({
          'chapter_id': chapterId,
          'title': title,
          'position': position,
          'xp_reward': xpReward,
        })
        .select()
        .single();
    return LessonSubChapter.fromJson(response);
  }

  Future<void> updateSubChapter({
    required String id,
    required String title,
    required int position,
    required int xpReward,
  }) async {
    await _supabase.from('lesson_sub_chapters').update({
      'title': title,
      'position': position,
      'xp_reward': xpReward,
    }).eq('id', id);
  }

  Future<void> deleteSubChapter(String id) async {
    await _supabase.from('lesson_sub_chapters').delete().eq('id', id);
  }

  // ------------------------------------------
  // PAGES
  // ------------------------------------------
  Future<List<LessonPage>> getPages(String subChapterId) async {
    final response = await _supabase
        .from('lesson_pages')
        .select()
        .eq('sub_chapter_id', subChapterId)
        .order('position', ascending: true);
    return (response as List).map((e) => LessonPage.fromJson(e)).toList();
  }

  Future<LessonPage> createPage({
    required String subChapterId,
    required int position,
  }) async {
    final response = await _supabase
        .from('lesson_pages')
        .insert({
          'sub_chapter_id': subChapterId,
          'position': position,
        })
        .select()
        .single();
    return LessonPage.fromJson(response);
  }

  Future<void> updatePage(String id, int position) async {
    await _supabase.from('lesson_pages').update({
      'position': position,
    }).eq('id', id);
  }

  Future<void> deletePage(String id) async {
    await _supabase.from('lesson_pages').delete().eq('id', id);
  }

  // ------------------------------------------
  // BLOCKS
  // ------------------------------------------
  Future<List<LessonBlock>> getBlocks(String pageId) async {
    final response = await _supabase
        .from('lesson_blocks')
        .select()
        .eq('page_id', pageId)
        .order('position', ascending: true);
    return (response as List).map((e) => LessonBlock.fromJson(e)).toList();
  }

  Future<void> saveBlocks(String pageId, List<LessonBlock> blocks) async {
    // 1. Delete all existing blocks for this page
    await _supabase.from('lesson_blocks').delete().eq('page_id', pageId);

    // 2. Insert new blocks
    if (blocks.isNotEmpty) {
      final payload = blocks.map((b) => {
        'page_id': pageId,
        'block_type': b.blockType,
        'content': b.content,
        'position': b.position,
      }).toList();
      await _supabase.from('lesson_blocks').insert(payload);
    }
  }
}
