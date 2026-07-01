import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../models/flashcard_models.dart';

class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  bool _isLoading = true;
  List<FlashcardDeck> _decks = [];
  List<FlashcardDeck> _filteredDecks = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDecks();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<FlashcardRepository>();
      final decks = await repo.getDecks();
      if (mounted) {
        setState(() {
          _decks = decks;
          _filteredDecks = decks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading decks: ${e.toString()}')),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDecks = _decks;
      } else {
        _filteredDecks = _decks
            .where((deck) =>
                deck.title.toLowerCase().contains(query) ||
                (deck.description?.toLowerCase().contains(query) ?? false))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id;

    // Filter into categories
    final myDecks = _filteredDecks.where((d) => d.creatorId == currentUserId).toList();
    final publicDecks = _filteredDecks.where((d) => d.creatorId != currentUserId && d.isPublic).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900, Colors.deepPurple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interactive Flashcards',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Master core concepts with active recall. Create your own decks or study public ones shared by others.',
                        style: TextStyle(
                          color: Colors.purple.shade100,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: const Icon(Icons.style, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search flashcard decks...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          if (_isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else ...[
            // 1. My Decks Section
            _buildSectionHeader(
              title: 'Your Flashcard Decks',
              subtitle: 'Decks you created and customize.',
              trailing: TextButton.icon(
                onPressed: () async {
                  final result = await context.push('/create-flashcard-deck');
                  if (result == true) _loadDecks();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Deck'),
                style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
              ),
            ),
            const SizedBox(height: 12),
            if (myDecks.isEmpty)
              _buildEmptyState(
                message: 'You have not created any decks yet.',
                actionLabel: 'Create Deck',
                onAction: () async {
                  final result = await context.push('/create-flashcard-deck');
                  if (result == true) _loadDecks();
                },
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myDecks.length,
                itemBuilder: (context, idx) => _buildDeckCard(myDecks[idx], isOwnDeck: true),
              ),
            const SizedBox(height: 32),

            // 2. Explore Public Decks Section
            _buildSectionHeader(
              title: 'Explore Public Decks',
              subtitle: 'Learn from decks created by the community.',
            ),
            const SizedBox(height: 12),
            if (publicDecks.isEmpty)
              _buildEmptyState(
                message: 'No public flashcard decks available yet.',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: publicDecks.length,
                itemBuilder: (context, idx) => _buildDeckCard(publicDecks[idx], isOwnDeck: false),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEmptyState({
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 16),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeckCard(FlashcardDeck deck, {required bool isOwnDeck}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => context.push(
          '/flashcard-deck/${deck.id}/play',
          extra: {'deckTitle': deck.title},
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Cover picture
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: Colors.deepPurple.shade50,
                  child: deck.imageUrl != null && deck.imageUrl!.isNotEmpty
                      ? Image.network(
                          deck.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) => const Icon(
                            Icons.style_rounded,
                            color: Colors.deepPurple,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.style_rounded,
                          color: Colors.deepPurple,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deck.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwnDeck)
                          Icon(
                            deck.isPublic ? Icons.public : Icons.lock_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (deck.description != null && deck.description!.isNotEmpty) ...[
                      Text(
                        deck.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOwnDeck ? Colors.deepPurple.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOwnDeck ? 'My Deck' : 'Public',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOwnDeck ? Colors.deepPurple.shade700 : Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isOwnDeck)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            onPressed: () => context.push(
                              '/my-flashcards/deck/${deck.id}/cards',
                              extra: {'deckTitle': deck.title},
                            ),
                            color: Colors.grey,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/flashcard-deck/${deck.id}/play',
                            extra: {'deckTitle': deck.title},
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text('Study'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
