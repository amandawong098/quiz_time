import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/widgets/flashcard_filter_bar.dart';
import '../../../core/services/ai_generation_manager.dart';
import '../models/flashcard_models.dart';
import '../../profile/widgets/user_detail_bottom_sheet.dart';

class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  bool _isLoading = true;
  List<FlashcardDeck> _decks = [];
  List<FlashcardDeck> _filteredDecks = [];
  String _searchQuery = '';
  String? _selectedRange;

  @override
  void initState() {
    super.initState();
    _loadDecks();
    AIGenerationManager().addListener(_onAIManagerStateChanged);
  }

  @override
  void dispose() {
    AIGenerationManager().removeListener(_onAIManagerStateChanged);
    super.dispose();
  }

  void _onAIManagerStateChanged() {
    if (mounted) {
      final task = AIGenerationManager().currentTask;
      if (task?.taskType == AITaskType.flashcard &&
          task?.status == AITaskStatus.completed) {
        _loadDecks();
      }
      setState(() {});
    }
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<FlashcardRepository>();
      final decks = await repo.getDecks();
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
          SnackBar(content: Text('Error loading decks: ${e.toString()}')),
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

        return matchesQuery && matchesRange;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedRange = null;
    });
    _applyFilters();
  }

  Widget _buildDeckCard(FlashcardDeck deck) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => context.push(
          '/flashcard-deck/${deck.id}/details',
          extra: {'deckTitle': deck.title},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Image or Gradient Banner (Deep Purple/Indigo)
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: deck.imageUrl == null || deck.imageUrl!.isEmpty
                    ? LinearGradient(
                        colors: [
                          Colors.deepPurple.shade700,
                          Colors.indigo.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: deck.imageUrl != null && deck.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(
                          deck.imageUrl!,
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: deck.imageUrl == null || deck.imageUrl!.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.style_rounded,
                        size: 28,
                        color: Colors.white70,
                      ),
                    )
                  : null,
            ),
            // Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (deck.description != null &&
                            deck.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            deck.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Footer Area: Card Count Badge & Author Chip
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🎴',
                                style: TextStyle(
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deck.cardCount == 1
                                    ? '1 Card'
                                    : '${deck.cardCount} Cards',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (deck.creatorId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              UserDetailBottomSheet.show(
                                context,
                                userId: deck.creatorId,
                                name: deck.creatorName ?? 'Author',
                                avatarUrl: deck.creatorAvatarUrl,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: Colors.deepPurple.shade100,
                                    backgroundImage: (deck.creatorAvatarUrl != null &&
                                            deck.creatorAvatarUrl!.isNotEmpty)
                                        ? NetworkImage(deck.creatorAvatarUrl!)
                                        : null,
                                    child: (deck.creatorAvatarUrl == null ||
                                            deck.creatorAvatarUrl!.isEmpty)
                                        ? const Icon(Icons.person, size: 9, color: Colors.deepPurple)
                                        : null,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      deck.creatorName ?? 'Author',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadDecks,
        color: Colors.deepPurple,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
            : _filteredDecks.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(20.0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
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
                            const SizedBox(height: 40),
                            Center(
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
                                    _searchQuery.isNotEmpty || _selectedRange != null
                                        ? 'No decks match your search'
                                        : 'No flashcard decks yet.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Builder(
                                    builder: (context) {
                                      final isAdmin = context.watch<AuthRepository>().isAdmin;
                                      return ElevatedButton.icon(
                                        onPressed: () async {
                                          if (isAdmin) {
                                            final result = await context.push('/create-flashcard-deck');
                                            if (result == true) {
                                              _loadDecks();
                                            }
                                          } else {
                                            context.push('/ai-flashcard-generator');
                                          }
                                        },
                                        icon: Icon(isAdmin ? Icons.add : Icons.auto_awesome),
                                        label: Text(isAdmin ? 'Create Deck' : 'Generate with AI'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(20.0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // AI Flashcard Generator Banner
                            InkWell(
                              onTap: () {
                                context.push('/ai-flashcard-generator');
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepPurple.shade600,
                                      Colors.purple.shade500,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple
                                          .withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.white24,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: Colors.amberAccent,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '✨ Generate Flashcards with AI',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Auto-generate high-yield study cards from topics or notes',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                            const SizedBox(height: 24),
                          ]),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.70,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final deck = _filteredDecks[index];
                              return _buildDeckCard(deck);
                            },
                            childCount: _filteredDecks.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: context.watch<AuthRepository>().isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final result = await context.push('/create-flashcard-deck');
                if (result == true) {
                  _loadDecks();
                }
              },
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
