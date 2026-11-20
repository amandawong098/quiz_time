import 'package:flutter/material.dart';
import '../services/ai_generation_manager.dart';

/// Shown on an AI generator screen when a different AI generation task
/// (e.g. Lesson, Flashcards, or Quiz) is already running.
class AIGenerationBusyView extends StatelessWidget {
  final AIGenerationTask activeTask;
  final String requestedFeatureName;

  const AIGenerationBusyView({
    super.key,
    required this.activeTask,
    required this.requestedFeatureName,
  });

  String _taskTypeLabel(AITaskType type) {
    switch (type) {
      case AITaskType.lesson:
        return 'Lesson';
      case AITaskType.flashcard:
        return 'Flashcard';
      case AITaskType.quiz:
        return 'Quiz';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLabel = _taskTypeLabel(activeTask.taskType);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(strokeWidth: 3.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI $activeLabel Generation in Progress',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Please wait until the current ${activeLabel.toLowerCase()} task finishes before generating a new $requestedFeatureName.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Text(
              activeTask.statusMessage,
              style: TextStyle(
                fontSize: 13,
                color: Colors.deepPurple.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFEDE7F6),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
