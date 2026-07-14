import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/learn/models/flashcard_models.dart';

class FlashcardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------
  // DECKS CRUD
  // ------------------------------------------

  // Fetch all viewable decks (public ones, or owned by current user)
  Future<List<FlashcardDeck>> getDecks() async {
    final response = await _supabase
        .from('flashcard_decks')
        .select('*, flashcards(id)')
        .order('created_at', ascending: false);
    return (response as List).map((e) => FlashcardDeck.fromJson(e)).toList();
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

  Future<void> deleteFlashcard(String id) async {
    await _supabase.from('flashcards').delete().eq('id', id);
  }
}
