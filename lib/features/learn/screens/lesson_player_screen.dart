import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/lesson_progress.dart';

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({super.key});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  int _currentSlide = 0; // 0: Reading, 1: Single Choice, 2: Multiple Choice
  final int _totalSlides = 3;
  final MockLessonProgress _progressTracker = MockLessonProgress();

  // Slide 2 (Single Choice) state
  int? _slide2SelectedIndex;
  bool _slide2Checked = false;
  bool? _slide2Correct;

  // Slide 3 (Multiple Choice) state
  final Set<int> _slide3SelectedIndices = {};
  bool _slide3Checked = false;
  bool? _slide3Correct;

  final List<String> _slide2Options = [
    '3: LOW, MEDIUM and HIGH',
    '2: ON and OFF',
  ];
  final int _slide2CorrectIndex = 1;

  final List<String> _slide3Options = [
    '0',
    '1',
    '-1',
    '2',
  ];
  final Set<int> _slide3CorrectIndices = {0, 1}; // '0' and '1' are correct

  Future<void> _handleBackPress() async {
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Lesson?'),
            content: const Text(
              'Are you sure you want to quit this lesson? Your progress for this sub-chapter will not be saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit && mounted) {
      context.pop();
    }
  }

  void _checkSlide2Answer(int index) {
    if (_slide2Checked) return;
    setState(() {
      _slide2SelectedIndex = index;
      _slide2Checked = true;
      _slide2Correct = index == _slide2CorrectIndex;
    });
  }

  void _checkSlide3Answer() {
    if (_slide3Checked) return;
    setState(() {
      _slide3Checked = true;
      // All correct must be selected, and no incorrect must be selected
      _slide3Correct = _slide3SelectedIndices.length == _slide3CorrectIndices.length &&
          _slide3SelectedIndices.every((i) => _slide3CorrectIndices.contains(i));
    });
  }

  void _completeLesson() {
    _progressTracker.complete('thinking_machine');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 72,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lesson Complete!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
              const Text(
                'You have successfully completed "Thinking Like a Machine". You can now proceed to the next lesson sub-chapter!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
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
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    context.pop(); // Return to dashboard
                  },
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCpuChipDiagram() {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade900,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // CPU Pins layout decoration
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    4,
                    (_) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // CPU Package center
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade400, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Icon(
                      Icons.memory,
                      color: Colors.green.shade300,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBinarySwitchesDiagram() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Switch blocks row
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSwitchBox('ON', '1', true),
                    const SizedBox(width: 8),
                    _buildSwitchBox('OFF', '0', false),
                    const SizedBox(width: 8),
                    _buildSwitchBox('OFF', '0', false),
                    const SizedBox(width: 8),
                    _buildSwitchBox('ON', '1', true),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            // Rocker switch graphic mockup
            Container(
              width: 32,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade500, width: 2),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            offset: const Offset(0, 2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'I',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'O',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchBox(String state, String value, bool isOn) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: isOn ? Colors.orange : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isOn ? 0.3 : 0.1),
                offset: const Offset(0, 2),
                blurRadius: isOn ? 4 : 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              state,
              style: TextStyle(
                color: isOn ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Computational Thinking',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'In the previous lesson, you learned that computers are really good at performing tiny simple operations very fast. Complex modern tasks like video streaming or online banking transactions can be broken down into these simple calculations.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 28),
          _buildCpuChipDiagram(),
          const SizedBox(height: 28),
          const Text(
            'In this lesson, you\'ll learn how to think like a computer to bring you one step closer to becoming a human-machine hybrid.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSingleChoiceSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How many different positions have the individual switches inside a computer?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: _slide2Options.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;

              final isSelected = _slide2SelectedIndex == index;
              final isCorrectOption = index == _slide2CorrectIndex;

              Color? cardColor;
              BorderSide borderSide = BorderSide(color: Colors.grey.shade300);

              if (_slide2Checked) {
                if (isCorrectOption) {
                  cardColor = Colors.green.shade200;
                  borderSide = BorderSide(color: Colors.green.shade400, width: 2);
                } else if (isSelected) {
                  cardColor = Colors.red.shade200;
                  borderSide = BorderSide(color: Colors.red.shade400, width: 2);
                }
              } else if (isSelected) {
                borderSide = const BorderSide(color: Colors.deepPurple, width: 2);
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: borderSide,
                ),
                child: RadioListTile<int>(
                  title: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: index,
                  groupValue: _slide2SelectedIndex,
                  activeColor: Colors.deepPurple,
                  onChanged: _slide2Checked
                      ? null
                      : (val) {
                          if (val != null) {
                            _checkSlide2Answer(val);
                          }
                        },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Computers use binary code to represent information. Binary means that there are only two possibilities for the state of a switch. To make things simpler, numbers are used to represent the OFF/ON states of a switch.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          _buildBinarySwitchesDiagram(),
          const SizedBox(height: 28),
          const Text(
            'Which numbers are used for the binary code?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: _slide3Options.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;

              final isSelected = _slide3SelectedIndices.contains(index);
              final isCorrectOption = _slide3CorrectIndices.contains(index);

              Color? cardColor;
              BorderSide borderSide = BorderSide(color: Colors.grey.shade300);

              if (_slide3Checked) {
                if (isCorrectOption) {
                  cardColor = Colors.green.shade200;
                  borderSide = BorderSide(color: Colors.green.shade400, width: 2);
                } else if (isSelected) {
                  cardColor = Colors.red.shade200;
                  borderSide = BorderSide(color: Colors.red.shade400, width: 2);
                }
              } else if (isSelected) {
                borderSide = const BorderSide(color: Colors.deepPurple, width: 2);
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: borderSide,
                ),
                child: CheckboxListTile(
                  title: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: isSelected,
                  activeColor: Colors.deepPurple,
                  onChanged: _slide3Checked
                      ? null
                      : (val) {
                          setState(() {
                            if (val == true) {
                              _slide3SelectedIndices.add(index);
                            } else {
                              _slide3SelectedIndices.remove(index);
                            }
                          });
                        },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCheckStatusBanner(bool isCorrect) {
    return Container(
      margin: const EdgeInsets.all(24.0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isCorrect ? 'Correct!' : 'Incorrect!',
            style: TextStyle(
              color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    // Current Slide logic
    if (_currentSlide == 0) {
      // Reading Slide: Always Continue button
      return Container(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _currentSlide = 1;
              });
            },
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      );
    } else if (_currentSlide == 1) {
      // Single Choice (Radio): Checked vs Idle
      if (_slide2Checked) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCheckStatusBanner(_slide2Correct ?? false),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentSlide = 2;
                    });
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // Idle radio state: Tapping options directly checks it, so no footer action yet
        return const SizedBox(height: 24);
      }
    } else {
      // Multiple Choice (Checkbox): Submit vs Continue
      if (_slide3Checked) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCheckStatusBanner(_slide3Correct ?? false),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _completeLesson,
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // Idle checkbox state: Submit button is required
        final hasSelection = _slide3SelectedIndices.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: hasSelection ? _checkSlide3Answer : null,
              child: const Text(
                'Submit Answer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progressRatio = (_currentSlide + 1) / _totalSlides;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: _handleBackPress,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressRatio,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
          ),
        ),
        body: Container(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentSlide == 0
                      ? _buildReadingSlide()
                      : (_currentSlide == 1
                          ? _buildSingleChoiceSlide()
                          : _buildMultipleChoiceSlide()),
                ),
              ),
              _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }
}
