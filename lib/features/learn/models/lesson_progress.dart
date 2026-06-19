class MockLessonProgress {
  static final MockLessonProgress _instance = MockLessonProgress._internal();
  factory MockLessonProgress() => _instance;
  MockLessonProgress._internal();

  final Set<String> completedSubChapters = {'humans_machines'};

  bool isCompleted(String id) => completedSubChapters.contains(id);

  bool isUnlocked(String id) {
    if (id == 'humans_machines') return true;
    if (id == 'thinking_machine') return completedSubChapters.contains('humans_machines');
    if (id == 'instructions_machines') return completedSubChapters.contains('thinking_machine');
    if (id == 'algorithms_flowcharts') return completedSubChapters.contains('instructions_machines');
    return false;
  }

  void complete(String id) {
    completedSubChapters.add(id);
  }
}
