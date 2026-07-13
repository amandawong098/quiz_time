import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../../core/widgets/flashcard_filter_bar.dart';
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
  String _searchQuery = '';
  String? _selectedRange;
  String _visibilityFilter = 'All'; // All, Public, Private

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<FlashcardRepository>();
      final decks = await repo.getMyDecks();
      if (mounted) {
        setState(() {
          _decks = decks;
          _isLoading = false;
        });
        _applyFilters();
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

  void _applyFilters() {
    setState(() {
      final query = _searchQuery.toLowerCase();
      _filteredDecks = _decks.where((deck) {
        // search query filter
        final matchesQuery = query.isEmpty ||
            deck.title.toLowerCase().contains(query) ||
            (deck.description?.toLowerCase().contains(query) ?? false);

        // card range filter
        bool matchesRange = true;
        if (_selectedRange != null) {
          final count = deck.cardCount;
          if (_selectedRange == '1-5') {
            matchesRange = count >= 1 && count <= 5;
          } else if (_selectedRange == '5-10') {
            matchesRange = count >= 5 && count <= 10;
          } else if (_selectedRange == '10-20') {
            matchesRange = count >= 10 && count <= 20;
          } else if (_selectedRange == '>20') {
            matchesRange = count > 20;
          }
        }

        // visibility filter
        bool matchesVisibility = true;
        if (_visibilityFilter == 'Public') {
          matchesVisibility = deck.isPublic;
        } else if (_visibilityFilter == 'Private') {
          matchesVisibility = !deck.isPublic;
        }

        return matchesQuery && matchesRange && matchesVisibility;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedRange = null;
      _visibilityFilter = 'All';
    });
    _applyFilters();
  }

  Widget _buildDeckCard(FlashcardDeck deck) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () async {
          final result = await context.push(
            '/flashcard-deck/${deck.id}/details',
            extra: {'deckTitle': deck.title},
          );
          if (result == true) {
            _loadDecks();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Left Cover Image / Icon (60x60, radius 12)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: deck.imageUrl == null || deck.imageUrl!.isEmpty
                      ? LinearGradient(
                          colors: [
                            Colors.deepPurple.shade600,
                            Colors.indigo.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: deck.imageUrl != null && deck.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(deck.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: deck.imageUrl == null || deck.imageUrl!.isEmpty
                    ? const Icon(
                        Icons.style_rounded,
                        size: 30,
                        color: Colors.white70,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Title & Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deck.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (deck.description != null && deck.description!.trim().isNotEmpty) ...[
                      Text(
                        deck.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Visibility Label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: deck.isPublic ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: deck.isPublic ? Colors.green.shade300 : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            deck.isPublic ? 'Public' : 'Private',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: deck.isPublic ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        // Card Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🎴  ${deck.cardCount} Cards',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Inline actions (Edit/Delete)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 22),
                    color: Colors.deepPurple.shade600,
                    tooltip: 'Edit deck',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final result = await context.push(
                        '/create-flashcard-deck',
                        extra: {'deck': deck},
                      );
                      if (result == true) {
                        _loadDecks();
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, size: 22),
                    color: Colors.red.shade600,
                    tooltip: 'Delete deck',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Deck'),
                          content: const Text(
                            'Are you sure you want to delete this deck? This will delete all cards inside it.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        try {
                          final repo = context.read<FlashcardRepository>();
                          await repo.deleteDeck(deck.id);
                          _loadDecks();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting deck: ${e.toString()}')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Flashcards',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Filter Bar
              FlashcardFilterBar(
                searchQuery: _searchQuery,
                selectedRange: _selectedRange,
                onSearchChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
                onRangeChanged: (v) {
                  setState(() => _selectedRange = v);
                  _applyFilters();
                },
                onReset: _resetFilters,
              ),
              const SizedBox(height: 12),
              // Visibility filter choice chips (All, Public, Private)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _visibilityFilter == 'All',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _visibilityFilter = 'All');
                          _applyFilters();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Public'),
                      selected: _visibilityFilter == 'Public',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _visibilityFilter = 'Public');
                          _applyFilters();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Private'),
                      selected: _visibilityFilter == 'Private',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _visibilityFilter = 'Private');
                          _applyFilters();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDecks,
                  color: Colors.deepPurple,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                      : _filteredDecks.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 100),
                                  child: Center(
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
                                          _searchQuery.isNotEmpty ||
                                                  _selectedRange != null ||
                                                  _visibilityFilter != 'All'
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
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredDecks.length,
                              itemBuilder: (context, index) {
                                final deck = _filteredDecks[index];
                                return _buildDeckCard(deck);
                              },
                            ),
                ),
              ),
            ],
          ),
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
