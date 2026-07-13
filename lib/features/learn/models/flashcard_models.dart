class FlashcardDeck {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String? imageUrl;
  final bool isPublic;
  final String? createdAt;
  final int cardCount;

  FlashcardDeck({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.imageUrl,
    this.isPublic = false,
    this.createdAt,
    this.cardCount = 0,
  });

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['flashcards'] is List) {
      count = (json['flashcards'] as List).length;
    } else if (json['card_count'] != null) {
      count = json['card_count'] as int;
    }
    return FlashcardDeck(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      cardCount: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'is_public': isPublic,
      'created_at': createdAt,
      'card_count': cardCount,
    };
  }
}

class FlashcardItem {
  final String id;
  final String deckId;
  final String front;
  final String back;
  final int position;

  FlashcardItem({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.position,
  });

  factory FlashcardItem.fromJson(Map<String, dynamic> json) {
    return FlashcardItem(
      id: json['id'] as String,
      deckId: json['deck_id'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deck_id': deckId,
      'front': front,
      'back': back,
      'position': position,
    };
  }
}
