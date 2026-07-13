import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../models/flashcard_models.dart';

class CreateFlashcardDeckScreen extends StatefulWidget {
  final FlashcardDeck? deck;
  const CreateFlashcardDeckScreen({super.key, this.deck});

  @override
  State<CreateFlashcardDeckScreen> createState() => _CreateFlashcardDeckScreenState();
}

class _CreateFlashcardDeckScreenState extends State<CreateFlashcardDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;
  bool _isSaving = false;

  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.deck != null) {
      _titleController.text = widget.deck!.title;
      _descController.text = widget.deck!.description ?? '';
      _isPublic = widget.deck!.isPublic;
      _imageUrl = widget.deck!.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final titleChanged = _titleController.text.trim() != (widget.deck?.title ?? '');
    final descChanged = _descController.text.trim() != (widget.deck?.description ?? '');
    final publicChanged = _isPublic != (widget.deck?.isPublic ?? false);
    return _imageFile != null || titleChanged || descChanged || publicChanged;
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
      messenger.showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
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

  Future<void> _saveDeck() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });

    final repo = context.read<FlashcardRepository>();
    final goRouter = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}';
        await Supabase.instance.client.storage
            .from('flashcard_images')
            .upload(fileName, _imageFile!);
        _imageUrl = Supabase.instance.client.storage
            .from('flashcard_images')
            .getPublicUrl(fileName);
      }

      final String deckId;
      if (widget.deck != null) {
        deckId = widget.deck!.id;
        await repo.updateDeck(
          id: deckId,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isPublic: _isPublic,
          imageUrl: _imageUrl,
        );
      } else {
        final newDeck = await repo.createDeck(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          isPublic: _isPublic,
          imageUrl: _imageUrl,
        );
        deckId = newDeck.id;
      }

      goRouter.pop(true);
      goRouter.push(
        '/my-flashcards/deck/$deckId/cards',
        extra: {'deckTitle': _titleController.text.trim()},
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving deck: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.deck != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final goRouter = GoRouter.of(context);
        if (!_isDirty || _isSaving) {
          goRouter.pop();
          return;
        }

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to discard them and exit?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldPop == true && mounted) {
          goRouter.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Deck Details' : 'Create Flashcard Deck',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image selector
                      GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.deepPurple.shade100,
                              width: 2,
                            ),
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : (_imageUrl != null && _imageUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                          child: _imageFile == null && (_imageUrl == null || _imageUrl!.isEmpty)
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 48,
                                      color: Colors.deepPurple.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Add Cover Image',
                                      style: TextStyle(
                                        color: Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Recommended: 16:9 ratio',
                                      style: TextStyle(
                                        color: Colors.deepPurple.shade300,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  alignment: Alignment.bottomRight,
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'Change',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Deck Title',
                          hintText: 'e.g., Biology Core Concepts',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a deck title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'What is this deck about?',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Privacy Switch
                      SwitchListTile(
                        title: const Text('Make this flashcard deck public'),
                        value: _isPublic,
                        onChanged: (val) => setState(() => _isPublic = val),
                      ),
                      const SizedBox(height: 40),

                      // Save Button
                      ElevatedButton.icon(
                        onPressed: _saveDeck,
                        icon: const Icon(Icons.save),
                        label: const Text('Save & Continue to Cards'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push(
                              '/flashcard-deck/${widget.deck!.id}/play',
                              extra: {'deckTitle': widget.deck!.title},
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Revision'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
