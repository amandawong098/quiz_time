import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/learn/models/flashcard_models.dart';

class FlashcardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------
  // DECKS CRUD
  // ------------------------------------------

  Future<List<FlashcardDeck>> getDecks() async {
    final response = await _supabase
        .from('flashcard_decks')
        .select('*, flashcards(id)')
        .order('created_at', ascending: false);
    final List<FlashcardDeck> decks =
        (response as List).map((e) => FlashcardDeck.fromJson(e)).toList();

    final creatorIds =
        decks.map((d) => d.creatorId).where((id) => id.isNotEmpty).toSet().toList();
    if (creatorIds.isNotEmpty) {
      try {
        final profilesRes = await _supabase
            .from('profiles')
            .select('id, name, avatar_url')
            .inFilter('id', creatorIds);
        final Map<String, Map<String, dynamic>> profileMap = {
          for (var p in (profilesRes as List))
            p['id'] as String: p as Map<String, dynamic>
        };

        for (var i = 0; i < decks.length; i++) {
          final p = profileMap[decks[i].creatorId];
          if (p != null) {
            decks[i] = FlashcardDeck(
              id: decks[i].id,
              creatorId: decks[i].creatorId,
              title: decks[i].title,
              description: decks[i].description,
              imageUrl: decks[i].imageUrl,
              isPublic: decks[i].isPublic,
              createdAt: decks[i].createdAt,
              cardCount: decks[i].cardCount,
              creatorName: p['name'] as String?,
              creatorAvatarUrl: p['avatar_url'] as String?,
            );
          }
        }
      } catch (_) {}
    }
    return decks;
  }

  // Fetch only decks created by the current user
  Future<List<FlashcardDeck>> getMyDecks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    
    final response = await _supabase
        .from('flashcard_decks')
        .select('*, flashcards(id)')
        .eq('creator_id', user.id)
        .order('created_at', ascending: false);
    return (response as List).map((e) => FlashcardDeck.fromJson(e)).toList();
  }
  Future<FlashcardDeck> getDeckById(String deckId) async {
    final response = await _supabase
        .from('flashcard_decks')
        .select('*, flashcards(id)')
        .eq('id', deckId)
        .single();
    return FlashcardDeck.fromJson(response);
  }
  Future<FlashcardDeck> createDeck({
    required String title,
    String? description,
    bool isPublic = false,
    String? imageUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    final response = await _supabase
        .from('flashcard_decks')
        .insert({
          'title': title,
          'description': description,
          'is_public': isPublic,
          'image_url': imageUrl,
          'creator_id': user?.id,
        })
        .select()
        .single();
    return FlashcardDeck.fromJson(response);
  }

  Future<void> updateDeck({
    required String id,
    required String title,
    String? description,
    bool isPublic = false,
    String? imageUrl,
  }) async {
    await _supabase
        .from('flashcard_decks')
        .update({
          'title': title,
          'description': description,
          'is_public': isPublic,
          'image_url': imageUrl,
        })
        .eq('id', id);
  }

  Future<void> deleteDeck(String id) async {
    await _supabase.from('flashcard_decks').delete().eq('id', id);
  }

  // ------------------------------------------
  // FLASHCARD ITEMS CRUD
  // ------------------------------------------

  // Fetch all cards in a deck ordered by position
  Future<List<FlashcardItem>> getFlashcards(String deckId) async {
    final response = await _supabase
        .from('flashcards')
        .select()
        .eq('deck_id', deckId)
        .order('position', ascending: true);
    return (response as List).map((e) => FlashcardItem.fromJson(e)).toList();
  }

  Future<FlashcardItem> createFlashcard({
    required String deckId,
    required String front,
    required String back,
    required int position,
  }) async {
    final response = await _supabase
        .from('flashcards')
        .insert({
          'deck_id': deckId,
          'front': front,
          'back': back,
          'position': position,
        })
        .select()
        .single();
    return FlashcardItem.fromJson(response);
  }

  Future<void> updateFlashcard({
    required String id,
    required String front,
    required String back,
    required int position,
  }) async {
    await _supabase
        .from('flashcards')
        .update({
          'front': front,
          'back': back,
          'position': position,
        })
        .eq('id', id);
  }

  Future<void> updatePositions(List<FlashcardItem> cards) async {
    final futures = <Future>[];
    for (int i = 0; i < cards.length; i++) {
      futures.add(
        _supabase
            .from('flashcards')
            .update({'position': i + 1})
            .eq('id', cards[i].id),
      );
    }
    await Future.wait(futures);
  }

  Future<void> deleteFlashcard(String id) async {
    await _supabase.from('flashcards').delete().eq('id', id);
  }
}
