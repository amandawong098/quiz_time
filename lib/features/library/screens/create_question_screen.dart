import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';

class _QuestionFormData {
  final String? id;
  final GlobalKey<FormState> formKey;
  final TextEditingController questionTextController;
  final TextEditingController durationController;
  final List<TextEditingController> optionControllers;
  final TextEditingController explanationController;
  bool isMultipleChoice;
  Set<int> correctOptionIndices;

  _QuestionFormData({
    this.id,
    required this.formKey,
    required this.questionTextController,
    required this.durationController,
    required this.optionControllers,
    required this.explanationController,
    this.isMultipleChoice = false,
    Set<int>? correctOptionIndices,
  }) : correctOptionIndices = correctOptionIndices ?? {0};

  void dispose() {
    questionTextController.dispose();
    durationController.dispose();
    explanationController.dispose();
    for (var c in optionControllers) {
      c.dispose();
    }
  }

  bool validateAndSave(BuildContext context, List<Option> outOptions) {
    if (formKey.currentState?.validate() == false) {
      return false;
    }

    if (questionTextController.text.trim().isEmpty) return false;
    if (durationController.text.trim().isEmpty) return false;

    if (optionControllers.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('At least two options are required per question')));
      return false;
    }

    if (correctOptionIndices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('At least one correct answer must be selected per question')));
      return false;
    }

    for (int i = 0; i < optionControllers.length; i++) {
      if (optionControllers[i].text.trim().isEmpty) continue;
      outOptions.add(
        Option(
          id: '',
          questionId: '',
          optionText: optionControllers[i].text.trim(),
          isCorrect: correctOptionIndices.contains(i),
        ),
      );
    }

    if (outOptions.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('At least two non-empty options are required per question')));
      return false;
    }
    return true;
  }
}

class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  const _AnimatedEntrance({required this.child, super.key});

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      child: FadeTransition(opacity: _animation, child: widget.child),
    );
  }
}

class CreateQuestionScreen extends StatefulWidget {
  final Quiz initialQuizData;
  final List<dynamic>? initialQuestionsData;
  const CreateQuestionScreen({
    super.key,
    required this.initialQuizData,
    this.initialQuestionsData,
  });

  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  final List<_QuestionFormData> _forms = [];

  @override
  void initState() {
    super.initState();
    _loadExistingQuestions();
  }

  @override
  void dispose() {
    for (var f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingQuestions() async {
    try {
      if (widget.initialQuestionsData != null &&
          widget.initialQuestionsData!.isNotEmpty) {
        setState(() {
          for (var qData in widget.initialQuestionsData!) {
            _forms.add(_createFormFromGeneratedData(qData));
          }
          _isLoading = false;
        });
        return;
      }

      if (widget.initialQuizData.id.isEmpty) {
        setState(() {
          _forms.add(_createNewForm());
          _isLoading = false;
        });
        return;
      }

      final repo = context.read<QuizRepository>();
      final data = await repo.getQuizDetails(widget.initialQuizData.id);
      final existingQs = data['questions'] as List<Question>;

      if (mounted) {
        setState(() {
          for (var q in existingQs) {
            _forms.add(_createFormFromQuestion(q));
          }
          if (_forms.isEmpty) {
            _forms.add(_createNewForm());
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _forms.add(_createNewForm());
        });
      }
    }
  }

  _QuestionFormData _createFormFromQuestion(Question q) {
    final correctIndices = <int>{};
    for (int i = 0; i < q.options.length; i++) {
      if (q.options[i].isCorrect) {
        correctIndices.add(i);
      }
    }
    if (correctIndices.isEmpty) {
      correctIndices.add(0);
    }
    return _QuestionFormData(
      id: q.id,
      formKey: GlobalKey<FormState>(),
      questionTextController: TextEditingController(text: q.questionText),
      durationController: TextEditingController(
        text: q.durationSeconds.toString(),
      ),
      optionControllers: q.options
          .map((o) => TextEditingController(text: o.optionText))
          .toList(),
      explanationController: TextEditingController(text: q.explanation ?? ''),
      isMultipleChoice: correctIndices.length > 1,
      correctOptionIndices: correctIndices,
    );
  }

  _QuestionFormData _createFormFromGeneratedData(Map<String, dynamic> qData) {
    final optionsData = qData['options'] as List;
    final correctIndices = <int>{};
    for (int i = 0; i < optionsData.length; i++) {
      if (optionsData[i]['isCorrect'] == true) {
        correctIndices.add(i);
      }
    }
    if (correctIndices.isEmpty) {
      correctIndices.add(0);
    }
    return _QuestionFormData(
      formKey: GlobalKey<FormState>(),
      questionTextController: TextEditingController(text: qData['text'] ?? ''),
      durationController: TextEditingController(
        text: (qData['durationSeconds'] ?? 30).toString(),
      ),
      optionControllers: optionsData
          .map((o) => TextEditingController(text: o['text'] ?? ''))
          .toList(),
      explanationController: TextEditingController(text: qData['explanation'] ?? ''),
      isMultipleChoice: correctIndices.length > 1,
      correctOptionIndices: correctIndices,
    );
  }

  _QuestionFormData _createNewForm() {
    return _QuestionFormData(
      formKey: GlobalKey<FormState>(),
      questionTextController: TextEditingController(),
      durationController: TextEditingController(text: '30'),
      optionControllers: [TextEditingController(), TextEditingController()],
      explanationController: TextEditingController(),
      isMultipleChoice: false,
      correctOptionIndices: {0},
    );
  }

  void _insertNewQuestion(int index) {
    setState(() {
      _forms.insert(index, _createNewForm());
    });
  }

  void _deleteQuestion(int index) {
    if (_forms.length == 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot delete the last question. Modify it instead.')));
      return;
    }
    setState(() {
      _forms[index].dispose();
      _forms.removeAt(index);
    });
  }

  Future<void> _saveAllToDatabase() async {
    List<Question> questionsToSave = [];

    for (int i = 0; i < _forms.length; i++) {
      var f = _forms[i];
      List<Option> opts = [];
      if (!f.validateAndSave(context, opts)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fix errors in Question ${i + 1}'),
          ),
        );
        return;
      }

      int duration = int.tryParse(f.durationController.text) ?? 30;

      questionsToSave.add(
        Question(
          id: f.id ?? '',
          quizId: widget.initialQuizData.id,
          questionText: f.questionTextController.text.trim(),
          durationSeconds: duration,
          orderIndex: i,
          explanation: f.explanationController.text.trim().isEmpty ? null : f.explanationController.text.trim(),
          options: opts,
        ),
      );
    }

    if (questionsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = context.read<QuizRepository>();
      String effectiveQuizId = widget.initialQuizData.id;

      // If it's a NEW quiz, create the quiz record NOW
      if (effectiveQuizId.isEmpty) {
        effectiveQuizId = await repo.createQuiz(widget.initialQuizData);
      }

      await repo.saveQuestions(effectiveQuizId, questionsToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz saved successfully!'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Widget _buildQuestionCard(
    _QuestionFormData formData,
    int index,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formData.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteQuestion(index),
                    tooltip: 'Delete Question',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: formData.durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (seconds)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(val.trim()) == null) {
                          return 'Must be a number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: formData.questionTextController,
                decoration: const InputDecoration(labelText: 'Question Title'),
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Question cannot be empty'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: formData.explanationController,
                decoration: const InputDecoration(
                  labelText: 'Explanation (optional)',
                  hintText: 'Provide context or explanation for the correct answer',
                ),
                maxLines: null,
              ),
              const SizedBox(height: 32),
              const Text(
                'Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formData.isMultipleChoice
                    ? 'Select all checkboxes corresponding to correct answers.'
                    : 'Select the radio button to mark the correct answer.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...List.generate(formData.optionControllers.length, (optIndex) {
                return Row(
                  children: [
                    if (formData.isMultipleChoice)
                      Checkbox(
                        value: formData.correctOptionIndices.contains(optIndex),
                        activeColor: Colors.deepPurple,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              formData.correctOptionIndices.add(optIndex);
                            } else {
                              formData.correctOptionIndices.remove(optIndex);
                            }
                          });
                        },
                      )
                    else
                      Radio<int>(
                        value: optIndex,
                        groupValue: formData.correctOptionIndices.isNotEmpty
                            ? formData.correctOptionIndices.first
                            : -1,
                        activeColor: Colors.deepPurple,
                        onChanged: (val) {
                          setState(() {
                            formData.correctOptionIndices = {val!};
                          });
                        },
                      ),
                    Expanded(
                      child: TextFormField(
                        controller: formData.optionControllers[optIndex],
                        decoration: InputDecoration(
                          labelText: 'Option ${optIndex + 1}',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              if (formData.optionControllers.length > 2) {
                                setState(() {
                                  formData.optionControllers[optIndex].dispose();
                                  formData.optionControllers.removeAt(optIndex);
                                  
                                  // Update correct indices set
                                  final newIndices = <int>{};
                                  for (var idx in formData.correctOptionIndices) {
                                    if (idx < optIndex) {
                                      newIndices.add(idx);
                                    } else if (idx > optIndex) {
                                      newIndices.add(idx - 1);
                                    }
                                  }
                                  if (newIndices.isEmpty) {
                                    newIndices.add(0);
                                  }
                                  formData.correctOptionIndices = newIndices;
                                });
                              }
                            },
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Option cannot be empty'
                            : null,
                      ),
                    ),
                  ],
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      formData.optionControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Multiple Choice (Checkbox)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                value: formData.isMultipleChoice,
                activeThumbColor: Colors.deepPurple,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    formData.isMultipleChoice = val;
                    if (!val) {
                      // Enforce single selection: keep only the first correct option (or default to 0)
                      if (formData.correctOptionIndices.isNotEmpty) {
                        final first = formData.correctOptionIndices.first;
                        formData.correctOptionIndices = {first};
                      } else {
                        formData.correctOptionIndices = {0};
                      }
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text('Are you sure you want to discard your changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (shouldPop == true) {
          if (mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Questions'),
          actions: [
            _isSaving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    onPressed: _saveAllToDatabase,
                    tooltip: 'Save Quiz',
                  ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ...List.generate(_forms.length, (index) {
                return _AnimatedEntrance(
                  key: ObjectKey(_forms[index]),
                  child: Column(
                    children: [
                      _buildQuestionCard(_forms[index], index),
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: () => _insertNewQuestion(index + 1),
                        icon: const Icon(
                          Icons.add_circle,
                          size: 36,
                          color: Colors.deepPurple,
                        ),
                        tooltip: 'Add Question Below',
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}
