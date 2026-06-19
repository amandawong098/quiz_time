import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/lesson_progress.dart';

class LessonsTab extends StatefulWidget {
  const LessonsTab({super.key});

  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  final MockLessonProgress _progressTracker = MockLessonProgress();
  bool _isChapterExpanded = true;
  String _selectedLessonCourse = 'Tech for Everyone';

  final List<Map<String, dynamic>> _subChapters = [
    {
      'id': 'humans_machines',
      'title': 'Humans vs Machines',
      'xp': 10,
    },
    {
      'id': 'thinking_machine',
      'title': 'Thinking Like a Machine',
      'xp': 10,
    },
    {
      'id': 'instructions_machines',
      'title': 'Giving Instructions to Machines',
      'xp': 10,
    },
    {
      'id': 'algorithms_flowcharts',
      'title': 'Algorithms & Flowcharts',
      'xp': 10,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    int completedCount = 0;
    for (var sub in _subChapters) {
      if (_progressTracker.isCompleted(sub['id'])) {
        completedCount++;
      }
    }
    final double progress = completedCount / _subChapters.length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Selection Dropdown
          Center(
            child: PopupMenuButton<String>(
              initialValue: _selectedLessonCourse,
              onSelected: (String value) {
                setState(() {
                  _selectedLessonCourse = value;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'Tech for Everyone',
                  child: Text(
                    'Tech for Everyone',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Introduction to Programming',
                  child: Text('Introduction to Programming'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedLessonCourse,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.deepPurple.shade900,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Course Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Collapsible Chapter Header Card
          GestureDetector(
            onTap: () {
              setState(() {
                _isChapterExpanded = !_isChapterExpanded;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill,
                    color: Colors.deepPurple.shade800,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'How to Think like a Coder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ),
                  Icon(
                    _isChapterExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.deepPurple.shade800,
                  ),
                ],
              ),
            ),
          ),

          // Sub-chapter list
          if (_isChapterExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: _subChapters.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final Map<String, dynamic> sub = entry.value;
                  final String id = sub['id'];
                  final String title = sub['title'];
                  final int xp = sub['xp'];

                  final bool isCompleted = _progressTracker.isCompleted(id);
                  final bool isUnlocked = _progressTracker.isUnlocked(id);
                  final bool isActive = isUnlocked && !isCompleted;

                  return GestureDetector(
                    onTap: () {
                      if (!isUnlocked) {
                        // Find previous incomplete chapter
                        String prevTitle = 'the previous lesson';
                        if (index > 0) {
                          prevTitle = _subChapters[index - 1]['title'];
                        }
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Lesson Locked'),
                            content: Text(
                              'Please complete "$prevTitle" first to unlock this lesson.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: isActive ? 2 : 0,
                      color: isUnlocked
                          ? Colors.white
                          : Colors.grey.shade50.withValues(alpha: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isActive
                              ? Colors.deepPurple.shade200
                              : Colors.grey.shade200,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                // Document icon leading
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isUnlocked
                                        ? Colors.deepPurple.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.description_outlined,
                                    color: isUnlocked
                                        ? Colors.deepPurple.shade700
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Sub-chapter Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lesson',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isUnlocked
                                              ? Colors.black87
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                      if (isUnlocked && !isCompleted) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'XP +$xp',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Trailing status
                                if (isCompleted)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 28,
                                  )
                                else if (!isUnlocked)
                                  Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey.shade400,
                                    size: 24,
                                  ),
                              ],
                            ),
                            // Learn button at the bottom of active card
                            if (isActive) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  await context.push('/learn/lesson-player');
                                  setState(() {}); // Refresh progress on return
                                },
                                child: const Text(
                                  'Learn',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
