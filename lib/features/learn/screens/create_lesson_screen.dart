import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../models/lesson_models.dart';
import '../../../core/services/publish_reward_service.dart';

class CreateLessonScreen extends StatefulWidget {
  final LessonCourse? lesson;
  const CreateLessonScreen({super.key, this.lesson});

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _imageUrl;
  File? _imageFile;
  bool _isLoading = false;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleController.text = widget.lesson!.title;
      _descController.text = widget.lesson!.description ?? '';
      _isPublic = widget.lesson!.isPublic;
      _imageUrl = widget.lesson!.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
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

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<LessonRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _isLoading = true);

    try {
      if (_imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split(Platform.pathSeparator).last}';
        await Supabase.instance.client.storage
            .from('lesson_images')
            .upload(fileName, _imageFile!);
        _imageUrl = Supabase.instance.client.storage
            .from('lesson_images')
            .getPublicUrl(fileName);
      }

      String courseId;
      if (widget.lesson != null) {
        final isAdmin = context.read<AuthRepository>().isAdmin;
        final effectiveIsPublic = isAdmin ? _isPublic : false;

        // Edit existing lesson
        await repo.updateCourse(
          id: widget.lesson!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isPublic: effectiveIsPublic,
          imageUrl: _imageUrl,
        );
        courseId = widget.lesson!.id;
      } else {
        final isAdmin = context.read<AuthRepository>().isAdmin;
        final effectiveIsPublic = isAdmin ? _isPublic : false;

        // Create new lesson
        final newCourse = await repo.createCourse(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isPublic: effectiveIsPublic,
          imageUrl: _imageUrl,
        );
        courseId = newCourse.id;
      }

      final isAdmin = context.read<AuthRepository>().isAdmin;
      if (_isPublic && mounted && !isAdmin) {
        final rewarded = await PublishRewardService.awardPublishXp(
          contentType: 'lesson',
          contentId: courseId,
        );
        if (rewarded && mounted) {
          await PublishRewardService.showPublishCongratsDialog(
            context,
            contentType: 'lesson',
          );
        }
      }

      if (mounted) {
        router.pop(true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null || _imageUrl != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.of(context);
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        if (shouldPop == true && mounted) {
          navigator.pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.lesson == null ? 'Create Lesson' : 'Edit Lesson'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.lesson == null) ...[
                  InkWell(
                    onTap: () {
                      context.push('/ai-lesson-generator');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade600,
                            Colors.indigo.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.auto_awesome,
                              color: Colors.amberAccent,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generate Lesson with AI ✨',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Auto-generate structured multi-page courses from topic or notes',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                                Icons.menu_book_rounded,
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
                  decoration: const InputDecoration(labelText: 'Lesson Title'),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Lesson Description (optional)'),
                  maxLines: 3,
                ),
                Builder(
                  builder: (context) {
                    final isAdmin = context.watch<AuthRepository>().isAdmin;
                    if (!isAdmin) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Make this lesson public'),
                          value: _isPublic,
                          onChanged: (val) => setState(() => _isPublic = val),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 12.0),
                          child: Text(
                            _isPublic
                                ? '💡 Ready to publish! Shared with the community to learn.'
                                : '💡 Save as draft. Only visible to you until published.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPublic ? Colors.deepPurple.shade700 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton.icon(
                    onPressed: _saveLesson,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Lesson'),
                  ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
