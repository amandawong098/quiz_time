import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../models/flashcard_models.dart';

class MyFlashcardsScreen extends StatefulWidget {
  const MyFlashcardsScreen({super.key});

  @override
  State<MyFlashcardsScreen> createState() => _MyFlashcardsScreenState();
}

class _MyFlashcardsScreenState extends State<MyFlashcardsScreen> {
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
      final decks = await repo.getMyDecks();
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
          SnackBar(content: Text('Error loading flashcards: ${e.toString()}')),
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

  Future<void> _deleteDeck(FlashcardDeck deck) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Deck'),
            content: Text('Are you sure you want to delete "${deck.title}"? This will delete all cards inside it.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && mounted) {
      try {
        final repo = context.read<FlashcardRepository>();
        await repo.deleteDeck(deck.id);
        _loadDecks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deck deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting deck: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Flashcards',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Search Bar & Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search decks...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredDecks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.style_outlined,
                                size: 72,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No decks match your search'
                                    : 'Create your first flashcard deck!',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await context.push('/create-flashcard-deck');
                                  if (result == true) {
                                    _loadDecks();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Deck'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _filteredDecks.length,
                          itemBuilder: (context, index) {
                            final deck = _filteredDecks[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              color: Colors.white,
                              child: InkWell(
                                onTap: () => context.push(
                                  '/my-flashcards/deck/${deck.id}/cards',
                                  extra: {'deckTitle': deck.title},
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      // Image
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
                                      // Text info
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
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Icon(
                                                  deck.isPublic
                                                      ? Icons.public
                                                      : Icons.lock_outline,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (deck.description != null &&
                                                deck.description!.isNotEmpty) ...[
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
                                            // Action chips/buttons row
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                                  onPressed: () async {
                                                    final result = await context.push(
                                                      '/create-flashcard-deck',
                                                      extra: {'deck': deck},
                                                    );
                                                    if (result == true) {
                                                      _loadDecks();
                                                    }
                                                  },
                                                  color: Colors.deepPurple,
                                                  tooltip: 'Edit details',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.style_outlined, size: 20),
                                                  onPressed: () => context.push(
                                                    '/my-flashcards/deck/${deck.id}/cards',
                                                    extra: {'deckTitle': deck.title},
                                                  ),
                                                  color: Colors.blue,
                                                  tooltip: 'Manage cards',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                                  onPressed: () => _deleteDeck(deck),
                                                  color: Colors.red,
                                                  tooltip: 'Delete deck',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/create-flashcard-deck');
          if (result == true) {
            _loadDecks();
          }
        },
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
