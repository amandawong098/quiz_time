import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublishRewardService {
  /// Awards 10 XP if the content item has not been rewarded for publishing yet.
  /// Returns true if XP was rewarded (should show congrats dialog), false otherwise.
  static Future<bool> awardPublishXp({
    required String contentType, // 'lesson', 'flashcard', 'quiz'
    required String contentId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      final key = '${contentType}_$contentId';
      final metadata = Map<String, dynamic>.from(user.userMetadata ?? {});

      List<String> rewardedList = [];
      if (metadata.containsKey('published_rewarded_content')) {
        final raw = metadata['published_rewarded_content'];
        if (raw is List) {
          rewardedList = raw.map((e) => e.toString()).toList();
        }
      }

      if (rewardedList.contains(key)) {
        return false; // Already rewarded previously!
      }

      rewardedList.add(key);
      metadata['published_rewarded_content'] = rewardedList;

      int currentXp = 0;
      int currentWeeklyXp = 0;
      if (metadata.containsKey('xp')) {
        currentXp = int.tryParse(metadata['xp'].toString()) ?? 0;
      }
      if (metadata.containsKey('weekly_xp')) {
        currentWeeklyXp = int.tryParse(metadata['weekly_xp'].toString()) ?? 0;
      }

      final nextXp = currentXp + 10;
      final nextWeeklyXp = currentWeeklyXp + 10;

      metadata['xp'] = nextXp;
      metadata['weekly_xp'] = nextWeeklyXp;

      // Update Auth user metadata
      await client.auth.updateUser(UserAttributes(data: metadata));

      // Update Profiles table
      await client.from('profiles').update({
        'xp': nextXp,
        'weekly_xp': nextWeeklyXp,
      }).eq('id', user.id);

      return true; // Successfully rewarded!
    } catch (_) {
      return false;
    }
  }

  /// Shows the congrats dialog for publishing content.
  static Future<void> showPublishCongratsDialog(
    BuildContext context, {
    required String contentType, // 'lesson', 'flashcard deck', 'quiz'
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.amber,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Congratulations! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'XP +10 Earned',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.deepPurple.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for publishing your $contentType to the community! We truly appreciate your effort in creating quality learning resources for everyone.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
