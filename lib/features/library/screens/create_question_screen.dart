import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import 'package:quiz_time/l10n/app_localizations.dart';

class _QuestionFormData {
  final GlobalKey<FormState> formKey;
  final TextEditingController questionTextController;
  final TextEditingController durationController;
  final List<TextEditingController> optionControllers;
  int correctOptionIndex;

  _QuestionFormData({
    required this.formKey,
    required this.questionTextController,
    required this.durationController,
    required this.optionControllers,
    this.correctOptionIndex = 0,
  });

  void dispose() {
    questionTextController.dispose();
    durationController.dispose();
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

    final l10n = AppLocalizations.of(context)!;
    if (optionControllers.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.atLeastTwoOptions)));
      return false;
    }

    for (int i = 0; i < optionControllers.length; i++) {
      if (optionControllers[i].text.trim().isEmpty) continue;
      outOptions.add(
        Option(
          id: '',
          questionId: '',
          optionText: optionControllers[i].text.trim(),
          isCorrect: i == correctOptionIndex,
        ),
      );
    }

    if (outOptions.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.atLeastTwoNonEmptyOptions)));
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
    int correctIdx = q.options.indexWhere((o) => o.isCorrect);
    return _QuestionFormData(
      formKey: GlobalKey<FormState>(),
      questionTextController: TextEditingController(text: q.questionText),
      durationController: TextEditingController(
        text: q.durationSeconds.toString(),
      ),
      optionControllers: q.options
          .map((o) => TextEditingController(text: o.optionText))
          .toList(),
      correctOptionIndex: correctIdx == -1 ? 0 : correctIdx,
    );
  }

  _QuestionFormData _createFormFromGeneratedData(Map<String, dynamic> qData) {
    final optionsData = qData['options'] as List;
    int correctIdx = optionsData.indexWhere((o) => o['isCorrect'] == true);
    return _QuestionFormData(
      formKey: GlobalKey<FormState>(),
      questionTextController: TextEditingController(text: qData['text'] ?? ''),
      durationController: TextEditingController(
        text: (qData['durationSeconds'] ?? 30).toString(),
      ),
      optionControllers: optionsData
          .map((o) => TextEditingController(text: o['text'] ?? ''))
          .toList(),
      correctOptionIndex: correctIdx == -1 ? 0 : correctIdx,
    );
  }

  _QuestionFormData _createNewForm() {
    return _QuestionFormData(
      formKey: GlobalKey<FormState>(),
      questionTextController: TextEditingController(),
      durationController: TextEditingController(text: '30'),
      optionControllers: [TextEditingController(), TextEditingController()],
      correctOptionIndex: 0,
    );
  }

  void _insertNewQuestion(int index) {
    setState(() {
      _forms.insert(index, _createNewForm());
    });
  }

  void _deleteQuestion(int index, AppLocalizations l10n) {
    if (_forms.length == 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteLastQuestion)));
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
            content: Text(
              AppLocalizations.of(context)!.fixErrorsInQuestion(i + 1),
            ),
          ),
        );
        return;
      }

      int duration = int.tryParse(f.durationController.text) ?? 30;

      questionsToSave.add(
        Question(
          id: '',
          quizId: widget.initialQuizData.id,
          questionText: f.questionTextController.text.trim(),
          durationSeconds: duration,
          orderIndex: i,
          options: opts,
        ),
      );
    }

    if (questionsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.addAtLeastOneQuestion),
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.quizSavedSuccessfully),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSave(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Widget _buildQuestionCard(
    _QuestionFormData formData,
    int index,
    AppLocalizations l10n,
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
                    '${l10n.questions} ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteQuestion(index, l10n),
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
                      decoration: InputDecoration(
                        labelText: l10n.durationSeconds,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n.required;
                        }
                        if (int.tryParse(val.trim()) == null) {
                          return l10n.mustBeANumber;
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
                decoration: InputDecoration(labelText: l10n.questionTitle),
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty
                    ? l10n.questionCannotBeEmpty
                    : null,
              ),
              const SizedBox(height: 32),
              Text(
                l10n.options,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.selectRadioButtonToMarkCorrect,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...List.generate(formData.optionControllers.length, (optIndex) {
                return Row(
                  children: [
                    Radio<int>(
                      value: optIndex,
                      groupValue: formData.correctOptionIndex,
                      onChanged: (val) {
                        setState(() => formData.correctOptionIndex = val!);
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: formData.optionControllers[optIndex],
                        decoration: InputDecoration(
                          labelText: l10n.optionNumber(optIndex + 1),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              if (formData.optionControllers.length > 2) {
                                setState(() {
                                  formData.optionControllers[optIndex]
                                      .dispose();
                                  formData.optionControllers.removeAt(optIndex);
                                  if (formData.correctOptionIndex >= optIndex &&
                                      formData.correctOptionIndex > 0) {
                                    formData.correctOptionIndex--;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? l10n.optionCannotBeEmpty
                            : null,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      formData.optionControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addOption),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            title: Text(l10n.discardChangesConfirmTitle),
            content: Text(l10n.discardChangesConfirmDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.discard,
                  style: const TextStyle(color: Colors.red),
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
          title: Text(l10n.editQuestions),
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
                : TextButton(
                    onPressed: _saveAllToDatabase,
                    child: Text(
                      l10n.saveQuiz,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                      _buildQuestionCard(_forms[index], index, l10n),
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
