import 'package:flutter/material.dart';

class Flashcard {
  final String category;
  final String front;
  final String back;
  final Color color;

  Flashcard({
    required this.category,
    required this.front,
    required this.back,
    required this.color,
  });
}

class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  final List<Flashcard> _flashcards = [
    Flashcard(
      category: 'Flutter',
      front: 'What is a Widget in Flutter?',
      back: 'Everything in Flutter is a Widget! Widgets are the basic building blocks of a Flutter app\'s user interface. They describe what their view should look like given their current configuration and state.',
      color: Colors.blue.shade800,
    ),
    Flashcard(
      category: 'Dart',
      front: 'What is the difference between final and const in Dart?',
      back: '`const` is compiled-time constant, whereas `final` is run-time constant. A `const` variable must be assigned a value during compilation, while a `final` variable can only be set once and its value is evaluated at runtime.',
      color: Colors.orange.shade800,
    ),
    Flashcard(
      category: 'Supabase',
      front: 'What is Supabase Realtime?',
      back: 'Supabase Realtime listens to database changes (inserts, updates, deletes) in PostgreSQL and broadcasts them to clients over WebSockets. This powers features like live notifications and chat applications.',
      color: Colors.green.shade800,
    ),
    Flashcard(
      category: 'State Management',
      front: 'What is Provider in Flutter?',
      back: 'Provider is a wrapper around InheritedWidget to make state management and dependency injection easier, cleaner, and highly reusable across the widget tree.',
      color: Colors.deepPurple.shade800,
    ),
  ];

  int _currentIndex = 0;
  final GlobalKey<_FlipCardState> _cardKey = GlobalKey<_FlipCardState>();

  void _nextCard() {
    _cardKey.currentState?.resetCard();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _flashcards.length;
    });
  }

  void _prevCard() {
    _cardKey.currentState?.resetCard();
    setState(() {
      _currentIndex = (_currentIndex - 1 + _flashcards.length) % _flashcards.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = _flashcards[_currentIndex];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900, Colors.deepPurple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interactive Flashcards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the card to flip and view the answer. Use flashcards to drill and memorize core concepts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Cards tracker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Decks: Development Essentials',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '${_currentIndex + 1} / ${_flashcards.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Flip card widget
          FlipCard(
            key: _cardKey,
            card: currentCard,
          ),
          const SizedBox(height: 24),

          // Interactive controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _prevCard,
                iconSize: 36,
                color: Colors.deepPurple,
                icon: const Icon(Icons.arrow_circle_left_rounded),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _cardKey.currentState?.flip();
                },
                icon: const Icon(Icons.flip_camera_android_rounded),
                label: const Text('Flip Card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextCard,
                iconSize: 36,
                color: Colors.deepPurple,
                icon: const Icon(Icons.arrow_circle_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Tips section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Active recall is the most effective way to study. Try answering before flipping the card.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FlipCard extends StatefulWidget {
  final Flashcard card;

  const FlipCard({
    super.key,
    required this.card,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep it in sync if widget changes
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
              ..setEntry(3, 2, 0.001) // perspective effect
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.deepPurple.shade50.withValues(alpha: 0.2)],
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
                    color: widget.card.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.card.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.card.color,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Icon(Icons.flip_camera_android_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
            Center(
              child: Text(
                widget.card.front,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'TAP TO FLIP',
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        height: 220,
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
                  child: Text(
                    widget.card.back,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'TAP TO RETURN',
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
