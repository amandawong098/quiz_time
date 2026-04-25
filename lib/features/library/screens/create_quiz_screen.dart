import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quiz_time/l10n/app_localizations.dart';

class CreateQuizScreen extends StatefulWidget {
  final Quiz? quiz;
  const CreateQuizScreen({super.key, this.quiz});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedGrade;
  String? _selectedSubject;
  bool _isPublic = false;
  bool _isLoading = true;
  bool _isGenerating = false;

  File? _imageFile;
  String? _imageUrl;

  List<dynamic>? _generatedQuestions;
  List<String> _grades = [];
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final repo = context.read<QuizRepository>();
      final grades = await repo.getGrades();
      final subjects = await repo.getSubjects();

      if (mounted) {
        setState(() {
          _grades = grades;
          _subjects = subjects;

          if (widget.quiz != null) {
            _titleController.text = widget.quiz!.title;
            _descController.text = widget.quiz!.description ?? '';
            _selectedGrade = widget.quiz!.grade;
            _selectedSubject = widget.quiz!.subject;
            _isPublic = widget.quiz!.isPublic;
            _imageUrl = widget.quiz!.imageUrl;
          } else {
            if (_grades.isNotEmpty) _selectedGrade = _grades.first;
            if (_subjects.isNotEmpty) _selectedSubject = _subjects.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorPickingImage(e.toString()),
          ),
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.gallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.camera),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleAiGenerationAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isGenerating = true);
    try {
      final gemini = context.read<GeminiService>();
      final result = await gemini.generateQuiz(
        title: title,
        description: _descController.text.trim(),
        grade: _selectedGrade,
        subject: _selectedSubject,
        numQuestions: 10,
      );

      _generatedQuestions = result['questions'];
      if (result['description'] != null) {
        _descController.text = result['description'];
      }

      await _proceedToQuestions();
    } catch (e) {
      setState(() => _isGenerating = false);
      if (e.toString().contains('MISSING_API_KEY')) {
        if (mounted) {
          _promptForApiKey(l10n);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    }
  }

  Future<void> _promptForApiKey(AppLocalizations l10n) async {
    final keyController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.apiKeyRequired),
        content: TextField(
          controller: keyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: l10n.enterApiKey,
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, keyController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_gemini_api_key', result);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.apiKeySaved)),
        );
        // Retry generation automatically
        _handleAiGenerationAndSave();
      }
    }
  }

  Future<void> _proceedToQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}';
        await Supabase.instance.client.storage
            .from('quiz_images')
            .upload(fileName, _imageFile!);
        _imageUrl = Supabase.instance.client.storage
            .from('quiz_images')
            .getPublicUrl(fileName);
      }

      final quizData = Quiz(
        id: widget.quiz?.id ?? '',
        creatorId: '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        grade: _selectedGrade ?? 'Grade 1',
        subject: _selectedSubject ?? 'Maths',
        isPublic: _isPublic,
        imageUrl: _imageUrl,
        createdAt: widget.quiz?.createdAt ?? DateTime.now(),
      );

      if (widget.quiz != null) {
        await context.read<QuizRepository>().updateQuiz(quizData);
      }

      if (mounted) {
        context
            .push(
              '/create-questions',
              extra: {
                'quiz': quizData,
                'generatedQuestions': _generatedQuestions,
              },
            )
            .then((_) {
              if (mounted) {
                context.pop();
              }
            });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorOccurred(e.toString()),
            ),
          ),
        );
        setState(() {
          _isLoading = false;
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _grades.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasImage = _imageFile != null || _imageUrl != null;

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
          title: Text(widget.quiz == null ? l10n.createQuiz : l10n.editQuiz),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!) as ImageProvider
                            : (_imageUrl != null
                                  ? NetworkImage(_imageUrl!)
                                  : null),
                        child: !hasImage
                            ? const Icon(
                                Icons.quiz,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: !hasImage ? Colors.deepPurple : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            icon: Icon(
                              !hasImage ? Icons.camera_alt : Icons.delete,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: !hasImage
                                ? _showImagePickerOptions
                                : () {
                                    setState(() {
                                      _imageFile = null;
                                      _imageUrl = null;
                                    });
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: l10n.quizTitle),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? l10n.pleaseEnterATitle
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(labelText: l10n.quizDescription),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: l10n.gradeLabel),
                  initialValue: _selectedGrade,
                  items: _grades.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedGrade = val!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: l10n.subjectLabel),
                  initialValue: _selectedSubject,
                  items: _subjects.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedSubject = val!);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.makeThisQuizPublic),
                  value: _isPublic,
                  onChanged: (val) => setState(() => _isPublic = val),
                ),
                const SizedBox(height: 32),
                if (_isLoading || _isGenerating)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  ElevatedButton.icon(
                    onPressed: _handleAiGenerationAndSave,
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Colors.deepPurple,
                    ),
                    label: Text(
                      l10n.generateWithAI,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade50,
                      elevation: 0,
                      side: BorderSide(color: Colors.deepPurple.shade100),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _proceedToQuestions,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.saveAndContinueToQuestions),
                  ),
                  if (widget.quiz != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/quiz/${widget.quiz!.id}');
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.startQuiz),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                  const SizedBox(height: 64),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
