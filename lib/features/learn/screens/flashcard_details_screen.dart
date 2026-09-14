import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flashcard_models.dart';
import '../widgets/flashcard_discussions_sheet.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../profile/widgets/user_detail_bottom_sheet.dart';

class FlashcardDetailsScreen extends StatefulWidget {
  final String deckId;
  const FlashcardDetailsScreen({super.key, required this.deckId});

  @override
  State<FlashcardDetailsScreen> createState() => _FlashcardDetailsScreenState();
}

class _FlashcardDetailsScreenState extends State<FlashcardDetailsScreen> {
  bool _isLoading = true;
  FlashcardDeck? _deck;
  List<FlashcardItem> _cards = [];
  Map<String, int> _cardDiscussionCounts = {};
  bool _shuffleCards = false;
  int _totalDiscussionsCount = 0;
  bool _hasPlayedBefore = false;
  bool _canPostDiscussion = false;

  @override
  void initState() {
    super.initState();
    _loadDeckDetails();
  }

  Future<void> _loadDeckDetails() async {
    setState(() => _isLoading = true);
    final discRepo = context.read<DiscussionRepository>();
    final flashcardRepo = context.read<FlashcardRepository>();
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final response = await client
          .from('flashcard_decks')
          .select('*, flashcards(id)')
          .eq('id', widget.deckId)
          .single();

      var deck = FlashcardDeck.fromJson(response);
      if (deck.creatorId.isNotEmpty &&
          (deck.creatorName == null || deck.creatorName!.isEmpty)) {
        try {
          final profileRes = await client
              .from('profiles')
              .select('name, avatar_url')
              .eq('id', deck.creatorId)
              .maybeSingle();
          if (profileRes != null) {
            deck = FlashcardDeck(
              id: deck.id,
              creatorId: deck.creatorId,
              title: deck.title,
              description: deck.description,
              imageUrl: deck.imageUrl,
              isPublic: deck.isPublic,
              createdAt: deck.createdAt,
              cardCount: deck.cardCount,
              creatorName: profileRes['name'] as String?,
              creatorAvatarUrl: profileRes['avatar_url'] as String?,
            );
          }
        } catch (_) {}
      }

      final count = await discRepo.getDeckTotalDiscussionsCount(widget.deckId);
      final cards = await flashcardRepo.getFlashcards(widget.deckId);
      final cardDiscussionCounts = await discRepo.getDeckCardsDiscussionsCount(widget.deckId);

      bool canPost = false;
      try {
        if (!mounted) return;
        final authRepo = context.read<AuthRepository>();
        final perm = await discRepo.checkLearnerCanPostDiscussion(
          userId: user?.id,
          isUserAdmin: authRepo.isAdmin,
          deckId: widget.deckId,
        );
        canPost = perm.canPost;
      } catch (_) {}

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
          _cards = cards;
          _cardDiscussionCounts = cardDiscussionCounts;
          _totalDiscussionsCount = count;
          _hasPlayedBefore = hasPlayed;
          _canPostDiscussion = canPost;
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
        isLocked: !context.read<AuthRepository>().isAdmin && !_hasPlayedBefore,
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
          Builder(
            builder: (context) {
              final isCreator = _deck?.creatorId ==
                  Supabase.instance.client.auth.currentUser?.id;
              final isAdmin = context.watch<AuthRepository>().isAdmin;
              if (isCreator || isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                  tooltip: 'Manage Cards',
                  onPressed: () async {
                    if (_deck != null) {
                      await context.push(
                        '/manage-cards/${_deck!.id}',
                        extra: _deck!.title,
                      );
                      if (mounted) {
                        _loadDeckDetails();
                      }
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (_canPostDiscussion)
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
                if (_deck!.creatorId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      UserDetailBottomSheet.show(
                        context,
                        userId: _deck!.creatorId,
                        name: _deck!.creatorName ?? 'Author',
                        avatarUrl: _deck!.creatorAvatarUrl,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.deepPurple.shade100,
                            backgroundImage: (_deck!.creatorAvatarUrl != null &&
                                    _deck!.creatorAvatarUrl!.isNotEmpty)
                                ? NetworkImage(_deck!.creatorAvatarUrl!)
                                : null,
                            child: (_deck!.creatorAvatarUrl == null ||
                                    _deck!.creatorAvatarUrl!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 11, color: Colors.deepPurple)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _deck!.creatorName ?? 'Author',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Badges/Chips
                Chip(
                  label: Text(
                    _deck!.cardCount == 1 ? '1 Card' : '${_deck!.cardCount} Cards',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.deepPurple.shade50,
                  side: BorderSide.none,
                ),
                const SizedBox(height: 32),
                if (context.watch<AuthRepository>().isAdmin)
                  _buildAdminCardInspection()
                else
                  Column(
                    children: [
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
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCardInspection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Admin Inspection Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.amber.shade900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Inspection Mode',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All card prompts (front) and answers (back) are directly visible below without interactive flipping.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Overview Header
        Text(
          'Cards Overview (${_cards.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),

        // Cards List
        if (_cards.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.style_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No flashcards found in this deck.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final card = _cards[index];
              final discussionCount = _cardDiscussionCounts[card.id] ?? 0;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Header: Badge + Discussions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.deepPurple.shade100,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.style_rounded,
                                  size: 14,
                                  color: Colors.deepPurple.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Card ${index + 1} of ${_cards.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_canPostDiscussion)
                            InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => FlashcardDiscussionsSheet(
                                    deckId: widget.deckId,
                                    cardId: card.id,
                                    deckTitle: _deck!.title,
                                    cardFrontText: card.front,
                                    cardNumber: index + 1,
                                    onTopicCreated: () => _loadDeckDetails(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
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
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 14,
                                      color: Colors.deepPurple,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$discussionCount',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Front (Prompt) Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurple.shade100.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'FRONT / PROMPT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              card.front.trim().isEmpty ? '(Empty front)' : card.front,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E1B4B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Connecting Icon Indicator
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Back (Answer) Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'BACK / ANSWER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              card.back.trim().isEmpty ? '(Empty back)' : card.back,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF064E3B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
