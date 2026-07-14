import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flashcard_models.dart';
import '../widgets/flashcard_discussions_sheet.dart';
import '../../../data/repositories/discussion_repository.dart';

class FlashcardDetailsScreen extends StatefulWidget {
  final String deckId;
  const FlashcardDetailsScreen({super.key, required this.deckId});

  @override
  State<FlashcardDetailsScreen> createState() => _FlashcardDetailsScreenState();
}

class _FlashcardDetailsScreenState extends State<FlashcardDetailsScreen> {
  bool _isLoading = true;
  FlashcardDeck? _deck;
  bool _shuffleCards = false;
  int _totalDiscussionsCount = 0;
  bool _hasPlayedBefore = false;

  @override
  void initState() {
    super.initState();
    _loadDeckDetails();
  }

  Future<void> _loadDeckDetails() async {
    setState(() => _isLoading = true);
    final discRepo = context.read<DiscussionRepository>();
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final response = await client
          .from('flashcard_decks')
          .select('*, flashcards(id)')
          .eq('id', widget.deckId)
          .single();

      final deck = FlashcardDeck.fromJson(response);
      final count = await discRepo.getDeckTotalDiscussionsCount(widget.deckId);

      final isCreator = deck.creatorId == user?.id;
      bool hasPlayed = isCreator;
      if (!isCreator && user != null) {
        final attemptsResponse = await client
            .from('flashcard_deck_attempts')
            .select('id')
            .eq('deck_id', widget.deckId)
            .eq('user_id', user.id)
            .limit(1);
        hasPlayed = (attemptsResponse as List).isNotEmpty;
      }

      if (mounted) {
        setState(() {
          _deck = deck;
          _totalDiscussionsCount = count;
          _hasPlayedBefore = hasPlayed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deck: ${e.toString()}')),
        );
      }
    }
  }

  void _showDeckDiscussions(BuildContext context) {
    if (_deck == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FlashcardDiscussionsSheet(
        deckId: _deck!.id,
        deckTitle: _deck!.title,
        isLocked: !_hasPlayedBefore,
        onTopicCreated: () {
          _loadDeckDetails();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    if (_deck == null) {
      return const Scaffold(
        body: Center(
          child: Text('Deck not found.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deck Details'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showDeckDiscussions(context),
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 22,
              color: Colors.white,
            ),
            label: Text(
              '$_totalDiscussionsCount',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeckDetails,
        color: Colors.deepPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cover Image / Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: _deck!.imageUrl == null || _deck!.imageUrl!.isEmpty
                        ? LinearGradient(
                            colors: [
                              Colors.deepPurple.shade700,
                              Colors.indigo.shade500,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: _deck!.imageUrl != null && _deck!.imageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_deck!.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _deck!.imageUrl == null || _deck!.imageUrl!.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.style_rounded,
                            size: 48,
                            color: Colors.white70,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  _deck!.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_deck!.description != null && _deck!.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    _deck!.description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Badges/Chips
                Chip(
                  label: Text(
                    _deck!.cardCount == 1 ? '1 Card' : '${_deck!.cardCount} Cards',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.deepPurple.shade50,
                  side: BorderSide.none,
                ),
                const SizedBox(height: 40),
                // Shuffle Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Shuffle Cards',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _shuffleCards,
                      activeThumbColor: Colors.deepPurple,
                      onChanged: (val) {
                        setState(() {
                          _shuffleCards = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Start Revision Button
                SizedBox(
                  width: 280,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                        '/flashcard-deck/${_deck!.id}/play?shuffle=$_shuffleCards',
                        extra: {'deckTitle': _deck!.title},
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Revision'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
