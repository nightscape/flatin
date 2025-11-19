import 'package:fsrs/fsrs.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'practice_item.dart';

/// Wrapper class that links a PracticeItem to an FSRS Card
class PracticeItemCard {
  /// Stable identifier based on item content
  final String itemId;

  /// The FSRS card instance
  final Card card;

  /// Last review date (UTC)
  final DateTime? lastReview;

  /// Due date (UTC)
  final DateTime due;

  PracticeItemCard({
    required this.itemId,
    required this.card,
    this.lastReview,
    required this.due,
  });

  /// Generate a stable ID for a PracticeItem based on its content
  static String generateItemId(PracticeItem item) {
    // Create a stable identifier from item content
    // Include: dataFileId, type, translation, and all forms
    final content = StringBuffer();
    content.write(item.dataFileId);
    content.write('|');
    content.write(item.type);
    content.write('|');
    content.write(item.translation);
    content.write('|');
    content.write(item.baseForm ?? '');
    content.write('|');
    // Include all forms in order
    for (final form in item.forms) {
      content.write(form);
      content.write('|');
    }

    // Create SHA-256 hash for stable ID
    final bytes = utf8.encode(content.toString());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a new card for a PracticeItem (due immediately)
  factory PracticeItemCard.createNew(PracticeItem item) {
    final itemId = generateItemId(item);
    final card = Card(cardId: itemId.hashCode);
    return PracticeItemCard(
      itemId: itemId,
      card: card,
      due: DateTime.now().toUtc(),
    );
  }

  /// Serialize to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'cardData': card.toMap(),
      'lastReview': lastReview?.toIso8601String(),
      'due': due.toIso8601String(),
    };
  }

  /// Deserialize from Map
  factory PracticeItemCard.fromMap(Map<String, dynamic> map) {
    return PracticeItemCard(
      itemId: map['itemId'] as String,
      card: Card.fromMap(map['cardData'] as Map<String, dynamic>),
      lastReview: map['lastReview'] != null
          ? DateTime.parse(map['lastReview'] as String)
          : null,
      due: DateTime.parse(map['due'] as String),
    );
  }

  /// Create a copy with updated values
  PracticeItemCard copyWith({
    String? itemId,
    Card? card,
    DateTime? lastReview,
    DateTime? due,
  }) {
    return PracticeItemCard(
      itemId: itemId ?? this.itemId,
      card: card ?? this.card,
      lastReview: lastReview ?? this.lastReview,
      due: due ?? this.due,
    );
  }
}
