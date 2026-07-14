import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../models/flashcard_models.dart';
import '../widgets/flashcard_discussions_sheet.dart';

class PlayFlashcardsScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;
  final bool shuffle;
  const PlayFlashcardsScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    this.shuffle = false,
  });

  @override
  State<PlayFlashcardsScreen> createState() => _PlayFlashcardsScreenState();
}

class _PlayFlashcardsScreenState extends State<PlayFlashcardsScreen> {
  bool _isLoading = true;
  List<FlashcardItem> _cards = [];
  int _currentIndex = 0;
  bool _isCardFlipped = false;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _xpEarned = 0;
  bool _isSessionEnded = false;
  final GlobalKey<_PlayFlipCardState> _cardKey = GlobalKey<_PlayFlipCardState>();
  Map<String, int> _cardDiscussionCounts = {};
  int _totalDiscussionsCount = 0;
  double _swipeOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<FlashcardRepository>();
      final discRepo = context.read<DiscussionRepository>();
      
      final cards = await repo.getFlashcards(widget.deckId);
      if (widget.shuffle) {
        cards.shuffle();
      }
      
      final counts = await discRepo.getDeckCardsDiscussionsCount(widget.deckId);
      final totalCount = await discRepo.getDeckTotalDiscussionsCount(widget.deckId);

      if (mounted) {
        setState(() {
          _cards = cards;
          _cardDiscussionCounts = counts;
          _totalDiscussionsCount = totalCount;
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

  void _onAnswered(bool correct) {
    if (correct) {
      _correctCount++;
    } else {
      _wrongCount++;
    }

    if (_currentIndex < _cards.length - 1) {
      _cardKey.currentState?.resetCard();
      setState(() {
        _isCardFlipped = false;
        _currentIndex++;
        _swipeOffset = 0.0;
      });
    } else {
      _endSession();
    }
  }

  Future<void> _endSession() async {
    setState(() => _isLoading = true);
    final int xpAwarded = _correctCount * 2;
    _xpEarned = xpAwarded;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('flashcard_deck_attempts').insert({
          'user_id': user.id,
          'deck_id': widget.deckId,
        });
      }
    } catch (e) {
      debugPrint('Error recording deck attempt: $e');
    }

    if (xpAwarded > 0) {
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
          final newXp = currentXp + xpAwarded;
          final newWeeklyXp = currentWeeklyXp + xpAwarded;

          // Update Auth user metadata
          await client.auth.updateUser(
            UserAttributes(
              data: {
                ...metadata ?? {},
                'xp': newXp,
                'weekly_xp': newWeeklyXp,
              },
            ),
          );

          // Update profiles table in public schema
          await client.from('profiles').update({
            'xp': newXp,
            'weekly_xp': newWeeklyXp,
          }).eq('id', user.id);
        }
      } catch (e) {
        debugPrint('Error updating XP: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSessionEnded = true;
      });
    }
  }

  void _showCardDiscussions(FlashcardItem card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FlashcardDiscussionsSheet(
        deckId: widget.deckId,
        cardId: card.id,
        deckTitle: widget.deckTitle,
        cardFrontText: card.front,
        cardNumber: _currentIndex + 1,
        onTopicCreated: () {
          _loadCards();
        },
      ),
    );
  }

  Widget _buildReviewScreen() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.stars_rounded,
              size: 100,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            const Text(
              'Revision Completed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Great job finishing this study session.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    '+$_xpEarned XP Earned 🏆',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '$_correctCount Correct',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '$_wrongCount Wrong',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/?tab=flashcards');
                },
                icon: const Icon(Icons.home, color: Colors.white),
                label: const Text('Back to Flashcards', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
    if (_isSessionEnded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Results'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => FlashcardDiscussionsSheet(
                    deckId: widget.deckId,
                    deckTitle: widget.deckTitle,
                    onTopicCreated: () {
                      _loadCards();
                    },
                  ),
                );
              },
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
        body: _buildReviewScreen(),
      );
    }

    return PopScope(
      canPop: _isSessionEnded || _cards.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final goRouter = GoRouter.of(context);
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Session?'),
            content: const Text(
              'Are you sure you want to exit this revision session? Your progress will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldPop == true && mounted) {
          goRouter.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.deckTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            if (_isCardFlipped && !_isLoading && _cards.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  _showCardDiscussions(_cards[_currentIndex]);
                },
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 22,
                  color: Colors.white,
                ),
                label: Text(
                  '${_cardDiscussionCounts[_cards[_currentIndex].id] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        body: Container(
          color: Colors.white,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _cards.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.style_outlined,
                              size: 72,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No cards in this deck yet.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context.pop(),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Study Session',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${_currentIndex + 1} / ${_cards.length}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.deepPurple),
                              ),
                            ],
                          ),
                           const SizedBox(height: 24),
                           GestureDetector(
                             onHorizontalDragUpdate: !_isCardFlipped ? null : (details) {
                               setState(() {
                                 _swipeOffset += details.primaryDelta ?? 0.0;
                               });
                             },
                             onHorizontalDragEnd: !_isCardFlipped ? null : (details) {
                               if (_swipeOffset > 120) {
                                 _onAnswered(true);
                               } else if (_swipeOffset < -120) {
                                 _onAnswered(false);
                               }
                               setState(() {
                                 _swipeOffset = 0.0;
                               });
                             },
                             child: Transform.translate(
                               offset: Offset(_swipeOffset, 0.0),
                               child: Transform.rotate(
                                 angle: _swipeOffset / 1000.0,
                                 child: Stack(
                                   children: [
                                     PlayFlipCard(
                                       key: _cardKey,
                                       card: _cards[_currentIndex],
                                       deckTitle: widget.deckTitle,
                                       onFlipped: (isFront) {
                                         setState(() {
                                           _isCardFlipped = !isFront;
                                         });
                                       },
                                     ),
                                     if (_swipeOffset != 0.0)
                                       Positioned.fill(
                                         child: IgnorePointer(
                                           child: Container(
                                             decoration: BoxDecoration(
                                               borderRadius: BorderRadius.circular(24),
                                               color: _swipeOffset > 0
                                                   ? Colors.green.withValues(alpha: (_swipeOffset / 240.0).clamp(0.0, 0.4))
                                                   : Colors.red.withValues(alpha: (-_swipeOffset / 240.0).clamp(0.0, 0.4)),
                                             ),
                                             alignment: _swipeOffset > 0 ? Alignment.centerLeft : Alignment.centerRight,
                                             padding: const EdgeInsets.all(24),
                                             child: Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                               decoration: BoxDecoration(
                                                 color: _swipeOffset > 0 ? Colors.green : Colors.red,
                                                 borderRadius: BorderRadius.circular(12),
                                                 border: Border.all(color: Colors.white, width: 2),
                                               ),
                                               child: Text(
                                                 _swipeOffset > 0 ? 'CORRECT' : 'WRONG',
                                                 style: const TextStyle(
                                                   color: Colors.white,
                                                   fontWeight: FontWeight.bold,
                                                   fontSize: 16,
                                                 ),
                                               ),
                                             ),
                                           ),
                                         ),
                                       ),
                                   ],
                                 ),
                               ),
                             ),
                           ),
                           const SizedBox(height: 32),
                          // Answer input actions / flip
                          _isCardFlipped
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _onAnswered(false),
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text('Wrong'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _onAnswered(true),
                                      icon: const Icon(Icons.check_circle_outline_rounded),
                                      label: const Text('Correct'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: SizedBox(
                                    width: 200,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _cardKey.currentState?.flip();
                                      },
                                      icon: const Icon(Icons.flip_camera_android_rounded),
                                      label: const Text('Flip Card'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 36),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.deepPurple.shade100),
                              ),
                              color: Colors.deepPurple.shade50.withValues(alpha: 0.3),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.swipe_rounded, color: Colors.deepPurple, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _isCardFlipped
                                            ? 'Hint: Swipe this card to the right to mark it Correct, or to the left to mark it Wrong!'
                                            : 'Hint: Tap to flip and reveal the answer, then use interactive swipe gestures to rate!',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade100),
                            ),
                            color: Colors.grey.shade50,
                            child: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Pro Tip: Try to recall the answer on the back before flipping the card to build stronger retention.',
                                      style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                                    ),
                                  ),
                                ],
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

class PlayFlipCard extends StatefulWidget {
  final FlashcardItem card;
  final String deckTitle;
  final Function(bool isFront)? onFlipped;
  const PlayFlipCard({
    super.key,
    required this.card,
    required this.deckTitle,
    this.onFlipped,
  });

  @override
  State<PlayFlipCard> createState() => _PlayFlipCardState();
}

class _PlayFlipCardState extends State<PlayFlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void resetCard() {
    _controller.reverse();
    setState(() {
      _isFront = true;
    });
    if (widget.onFlipped != null) {
      widget.onFlipped!(true);
    }
  }

  void flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
    if (widget.onFlipped != null) {
      widget.onFlipped!(_isFront);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final double value = _animation.value;
          final double angle = value * 3.141592653589793;
          final isBack = angle >= 3.141592653589793 / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(3.141592653589793),
                    alignment: Alignment.center,
                    child: _buildCardBack(),
                  )
                : _buildCardFront(),
          );
        },
      ),
    );
  }

  Widget _buildCardFront() {
    return Card(
      elevation: 4,
      shadowColor: Colors.deepPurple.shade100.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.deepPurple.shade50),
      ),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.deepPurple.shade50.withValues(alpha: 0.1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.deckTitle.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.flip_camera_android_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  widget.card.front,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            Text(
              'TAP TO REVEAL ANSWER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Card(
      elevation: 4,
      shadowColor: Colors.deepPurple.shade100.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade800],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ANSWER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white60, size: 20),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    widget.card.back,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'TAP TO RETURN TO QUESTION',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
