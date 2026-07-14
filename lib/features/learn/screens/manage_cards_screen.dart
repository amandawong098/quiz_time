import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../models/flashcard_models.dart';

class ManageCardsScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;
  const ManageCardsScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
  });

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  bool _isLoading = true;
  List<FlashcardItem> _cards = [];
  FlashcardDeck? _deck;

  @override
  void initState() {
    super.initState();
    _loadCards();
    _loadDeckDetails();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<FlashcardRepository>();
      final cards = await repo.getFlashcards(widget.deckId);
      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cards: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadDeckDetails() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('flashcard_decks')
          .select('*, flashcards(id)')
          .eq('id', widget.deckId)
          .single();
      if (mounted) {
        setState(() {
          _deck = FlashcardDeck.fromJson(response);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _showAddEditCardDialog([FlashcardItem? card]) {
    final isEditing = card != null;
    final frontController = TextEditingController(text: card?.front ?? '');
    final backController = TextEditingController(text: card?.back ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Card' : 'Add New Card'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: frontController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Front / Question',
                      hintText: 'What goes on the front of the card?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter front text';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: backController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Back / Answer',
                      hintText: 'What goes on the back of the card?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter back text';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final repo = context.read<FlashcardRepository>();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Dismiss dialog
                
                setState(() => _isLoading = true);
                try {
                  if (isEditing) {
                    await repo.updateFlashcard(
                      id: card.id,
                      front: frontController.text.trim(),
                      back: backController.text.trim(),
                      position: card.position,
                    );
                  } else {
                    await repo.createFlashcard(
                      deckId: widget.deckId,
                      front: frontController.text.trim(),
                      back: backController.text.trim(),
                      position: _cards.length + 1,
                    );
                  }
                  _loadCards();
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error saving card: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCard(FlashcardItem card) async {
    final repo = context.read<FlashcardRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Card'),
            content: const Text('Are you sure you want to delete this card?'),
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
      setState(() => _isLoading = true);
      try {
        await repo.deleteFlashcard(card.id);
        _loadCards();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          messenger.showSnackBar(
            SnackBar(content: Text('Error deleting card: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _deck?.title ?? widget.deckTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit' && _deck != null) {
                final result = await context.push(
                  '/create-flashcard-deck',
                  extra: {'deck': _deck},
                );
                if (result == true && mounted) {
                  _loadDeckDetails();
                }
              } else if (value == 'delete' && _deck != null) {
                final repo = context.read<FlashcardRepository>();
                final goRouter = GoRouter.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Deck'),
                        content: Text('Are you sure you want to delete "${_deck!.title}"? This will delete all cards inside it.'),
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
                    await repo.deleteDeck(_deck!.id);
                    goRouter.pop(true);
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error deleting deck: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text('Edit Deck Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Deck', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _cards.isEmpty
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
                        const Text(
                          'No cards in this deck yet.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first question and answer!',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditCardDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Card'),
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
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _cards.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final repo = context.read<FlashcardRepository>();
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      setState(() {
                        final FlashcardItem item = _cards.removeAt(oldIndex);
                        _cards.insert(newIndex, item);
                        _isLoading = true;
                      });
                      try {
                        await repo.updatePositions(_cards);
                        await _loadCards();
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Error updating card order: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      return Card(
                        key: ValueKey(card.id),
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.deepPurple.shade50,
                                    child: Text(
                                      '${card.position}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Drag to reorder',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _showAddEditCardDialog(card),
                                    color: Colors.deepPurple,
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                    onPressed: () => _deleteCard(card),
                                    color: Colors.red,
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'FRONT / QUESTION',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.front,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Divider(height: 24),
                              const Text(
                                'BACK / ANSWER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.back,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: _cards.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditCardDialog(),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
