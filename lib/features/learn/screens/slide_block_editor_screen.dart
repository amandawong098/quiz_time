import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../models/lesson_models.dart';
import '../../../core/widgets/video_preview_widget.dart';

class SlideBlockEditorScreen extends StatefulWidget {
  final String pageId;
  final String pageTitle;
  const SlideBlockEditorScreen({
    super.key,
    required this.pageId,
    required this.pageTitle,
  });

  @override
  State<SlideBlockEditorScreen> createState() => _SlideBlockEditorScreenState();
}

class _SlideBlockEditorScreenState extends State<SlideBlockEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  List<LessonBlock> _blocks = [];

  int get _totalTextLength {
    int length = 0;
    for (var b in _blocks) {
      if (b.blockType == 'text') {
        final ctrl = _textControllers[b.id];
        if (ctrl != null) {
          length += ctrl.text.length;
        } else {
          length += (b.content['text'] as String? ?? '').length;
        }
      }
    }
    return length;
  }

  bool get _isTooLong {
    return _blocks.length > 4 || _totalTextLength > 500;
  }

  // Controllers mapped to block ID for text and media fields
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, TextEditingController> _captionControllers = {};
  final Map<String, TextEditingController> _questionControllers = {};
  final Map<String, List<TextEditingController>> _optionControllers = {};
  final Map<String, TextEditingController> _explanationControllers = {};

  // Block error messages mapping block ID -> error text
  final Map<String, String> _blockErrors = {};

  void _clearError(String blockId) {
    if (_blockErrors.containsKey(blockId)) {
      setState(() {
        _blockErrors.remove(blockId);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var c in _textControllers.values) {
      c.dispose();
    }
    for (var c in _captionControllers.values) {
      c.dispose();
    }
    for (var c in _questionControllers.values) {
      c.dispose();
    }
    for (var c in _explanationControllers.values) {
      c.dispose();
    }
    for (var list in _optionControllers.values) {
      for (var c in list) {
        c.dispose();
      }
    }
    _textControllers.clear();
    _captionControllers.clear();
    _questionControllers.clear();
    _optionControllers.clear();
    _explanationControllers.clear();
  }

  Future<void> _loadBlocks() async {
    setState(() => _isLoading = true);
    _disposeControllers();

    try {
      final repo = context.read<LessonRepository>();
      final blocks = await repo.getBlocks(widget.pageId);

      setState(() {
        _blocks = blocks;
        _isLoading = false;
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading blocks: ${e.toString()}')),
      );
    }
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  // Formatting insert utility
  void _insertFormatting(
      TextEditingController controller, String prefix, String suffix) {
    _markChanged();
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start >= 0 && end >= start) {
      final selectedText = text.substring(start, end);
      final newText =
          text.replaceRange(start, end, '$prefix$selectedText$suffix');
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: start + prefix.length + selectedText.length,
      );
    } else {
      final currentPosition = selection.baseOffset;
      if (currentPosition >= 0) {
        final newText = text.replaceRange(
            currentPosition, currentPosition, '$prefix$suffix');
        controller.text = newText;
        controller.selection =
            TextSelection.collapsed(offset: currentPosition + prefix.length);
      } else {
        controller.text = text + prefix + suffix;
      }
    }
  }

  // Supabase storage media file upload
  Future<String?> _uploadFile(PlatformFile file) async {
    try {
      final client = Supabase.instance.client;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = 'lessons/$fileName';

      if (file.bytes != null) {
        await client.storage.from('discussion_attachments').uploadBinary(path, file.bytes!);
      } else if (file.path != null) {
        final fileIo = File(file.path!);
        await client.storage.from('discussion_attachments').upload(path, fileIo);
      } else {
        return null;
      }

      return client.storage.from('discussion_attachments').getPublicUrl(path);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
      return null;
    }
  }

  Future<String?> _uploadXFile(XFile file) async {
    try {
      final client = Supabase.instance.client;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = 'lessons/$fileName';

      final fileIo = File(file.path);
      await client.storage.from('discussion_attachments').upload(path, fileIo);

      return client.storage.from('discussion_attachments').getPublicUrl(path);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
      return null;
    }
  }

  // ------------------------------------------
  // BLOCK CRUD
  // ------------------------------------------
  void _addBlock(String type) {
    _markChanged();
    setState(() {
      Map<String, dynamic> initialContent = {};
      if (type == 'text') {
        initialContent = {'text': ''};
      } else if (type == 'media') {
        initialContent = {'url': '', 'type': 'image', 'caption': ''};
      } else if (type == 'test') {
        initialContent = {
          'question': '',
          'is_multiple_choice': false,
          'options': [
            {'text': '', 'is_correct': true},
            {'text': '', 'is_correct': false},
          ]
        };
      } else if (type == 'file') {
        initialContent = {'url': '', 'name': '', 'size': ''};
      }

      final newBlock = LessonBlock(
        id: 'new_${DateTime.now().millisecondsSinceEpoch}_${_blocks.length}',
        pageId: widget.pageId,
        blockType: type,
        content: initialContent,
        position: _blocks.length,
      );

      _blocks.add(newBlock);
    });
  }

  void _deleteBlock(int index) {
    _markChanged();
    final block = _blocks[index];
    setState(() {
      _blocks.removeAt(index);
      _blockErrors.remove(block.id);
    });
  }

  void _moveBlock(int index, bool moveUp) {
    if (moveUp && index == 0) return;
    if (!moveUp && index == _blocks.length - 1) return;

    _markChanged();
    setState(() {
      final targetIndex = moveUp ? index - 1 : index + 1;
      final block = _blocks.removeAt(index);
      _blocks.insert(targetIndex, block);
    });
  }

  Future<void> _saveChanges() async {
    final repo = context.read<LessonRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final List<LessonBlock> updatedBlocks = [];
    final Map<String, String> errors = {};

    for (int i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      Map<String, dynamic> content = Map.from(b.content);

      if (b.blockType == 'text') {
        final ctrl = _textControllers[b.id];
        final text = ctrl?.text.trim() ?? '';
        if (text.isEmpty) {
          errors[b.id] = 'Text block cannot be empty.';
        }
        content['text'] = ctrl?.text ?? (b.content['text'] ?? '');
      } else if (b.blockType == 'media') {
        final ctrl = _captionControllers[b.id];
        content['caption'] = ctrl?.text ?? (b.content['caption'] ?? '');
        final url = b.content['url'] as String? ?? '';
        if (url.trim().isEmpty) {
          errors[b.id] = 'Media block must have an image or video uploaded.';
        }
      } else if (b.blockType == 'file') {
        final url = b.content['url'] as String? ?? '';
        if (url.trim().isEmpty) {
          errors[b.id] = 'File block must have a file uploaded.';
        }
      } else if (b.blockType == 'test') {
        final qCtrl = _questionControllers[b.id];
        final qText = qCtrl?.text.trim() ?? '';
        if (qText.isEmpty) {
          errors[b.id] = 'Question text cannot be empty.';
        }
        content['question'] = qCtrl?.text ?? (b.content['question'] ?? '');

        final expCtrl = _explanationControllers[b.id];
        content['explanation'] = expCtrl?.text.trim() ?? (b.content['explanation'] ?? '');

        // Options
        final optCtrls = _optionControllers[b.id] ?? [];
        if (optCtrls.length < 2) {
          errors[b.id] = 'Test block must have at least 2 options.';
        }

        final List<dynamic> originalOpts = b.content['options'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> finalOpts = [];

        for (int optIdx = 0; optIdx < optCtrls.length; optIdx++) {
          final optText = optCtrls[optIdx].text.trim();
          if (optText.isEmpty) {
            errors[b.id] = 'Option ${optIdx + 1} cannot be empty.';
          }
          final isCorrect = optIdx < originalOpts.length
              ? ((originalOpts[optIdx] as Map)['is_correct'] as bool? ?? false)
              : false;
          finalOpts.add({
            'text': optCtrls[optIdx].text,
            'is_correct': isCorrect,
          });
        }

        final hasCorrect = finalOpts.any((opt) => opt['is_correct'] == true);
        if (!hasCorrect && !errors.containsKey(b.id)) {
          errors[b.id] = 'Test block must have at least one correct option checked.';
        }

        content['options'] = finalOpts;
      }

      updatedBlocks.add(LessonBlock(
        id: b.id.startsWith('new_') ? '' : b.id,
        pageId: b.pageId,
        blockType: b.blockType,
        content: content,
        position: i,
      ));
    }

    if (errors.isNotEmpty) {
      setState(() {
        _blockErrors.clear();
        _blockErrors.addAll(errors);
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please resolve the errors highlighted in red before saving.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isTooLong) {
      final confirmSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Page Content Too Long?'),
          content: Text(
            'This slide contains a lot of content (${_blocks.length} blocks / $_totalTextLength characters). '
            'To optimize for mobile readability, we recommend a maximum of 4 blocks and 500 characters per slide. '
            'Do you want to save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (confirmSave != true) {
        return;
      }
      if (!mounted) return;
    }

    setState(() => _isSaving = true);
    try {
      await repo.saveBlocks(widget.pageId, updatedBlocks);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Slide saved successfully!')),
      );
      router.pop(true); // Return true to refresh slides view
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: ${e.toString()}')),
      );
    }
  }

  // ------------------------------------------
  // BLOCK RENDERING & EDITORS
  // ------------------------------------------
  Widget _buildBlockEditor(LessonBlock block, int index) {
    Widget editorBody = const SizedBox();

    if (block.blockType == 'text') {
      editorBody = _buildTextBlockEditor(block, index);
    } else if (block.blockType == 'media') {
      editorBody = _buildMediaBlockEditor(block, index);
    } else if (block.blockType == 'test') {
      editorBody = _buildTestBlockEditor(block, index);
    } else if (block.blockType == 'file') {
      editorBody = _buildFileBlockEditor(block, index);
    }

    final hasError = _blockErrors.containsKey(block.id);
    final errorText = _blockErrors[block.id];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasError ? Colors.red.shade700 : Colors.grey.shade200,
          width: hasError ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Block Header Actions
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasError ? Colors.red.shade50 : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${block.blockType.toUpperCase()} BLOCK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasError ? Colors.red.shade700 : Colors.deepPurple.shade700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: index == 0 ? null : () => _moveBlock(index, true),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: index == _blocks.length - 1
                      ? null
                      : () => _moveBlock(index, false),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  onPressed: () => _deleteBlock(index),
                ),
              ],
            ),
            const Divider(height: 24),
            editorBody,
            if (hasError && errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                errorText,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This slide page contains a lot of content. We recommend splitting it across multiple slide pages to keep the lesson bite-sized for mobile screens.',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBlockEditor(LessonBlock block, int index) {
    if (!_textControllers.containsKey(block.id)) {
      _textControllers[block.id] =
          TextEditingController(text: block.content['text'] ?? '')
            ..addListener(() {
              setState(() {
                _markChanged();
                _clearError(block.id);
              });
            });
    }
    final ctrl = _textControllers[block.id]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Formatting Toolbar Row (H1-H6, Bold, Italic, Underline, Strikethrough, Bullets)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PopupMenuButton<int>(
                  icon: const Text('H',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: 'Headings',
                  onSelected: (h) {
                    final hashes = '#' * h;
                    _insertFormatting(ctrl, '$hashes ', '');
                  },
                  itemBuilder: (context) => List.generate(
                    3,
                    (idx) => PopupMenuItem(
                      value: idx + 1,
                      child: Text('Heading ${idx + 1}',
                          style: TextStyle(
                              fontSize: (20 - idx * 2).toDouble(),
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.format_bold, size: 18),
                  tooltip: 'Bold',
                  onPressed: () => _insertFormatting(ctrl, '**', '**'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic, size: 18),
                  tooltip: 'Italic',
                  onPressed: () => _insertFormatting(ctrl, '*', '*'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_underlined, size: 18),
                  tooltip: 'Underline',
                  onPressed: () => _insertFormatting(ctrl, '<u>', '</u>'),
                ),
                IconButton(
                  icon: const Icon(Icons.strikethrough_s, size: 18),
                  tooltip: 'Strikethrough',
                  onPressed: () => _insertFormatting(ctrl, '~~', '~~'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted, size: 18),
                  tooltip: 'Bullet List',
                  onPressed: () => _insertFormatting(ctrl, '• ', ''),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: null,
          minLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter lesson text here (supports Markdown style)...',
          ),
        ),
      ],
    );
  }

  Widget _buildMediaBlockEditor(LessonBlock block, int index) {
    if (!_captionControllers.containsKey(block.id)) {
      _captionControllers[block.id] =
          TextEditingController(text: block.content['caption'] ?? '')
            ..addListener(() {
              _markChanged();
              _clearError(block.id);
            });
    }
    final captionCtrl = _captionControllers[block.id]!;
    final url = block.content['url'] as String? ?? '';
    final mediaType = block.content['type'] as String? ?? 'image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url.isNotEmpty) ...[
          mediaType == 'video'
              ? VideoPreviewWidget(
                  videoUrl: url,
                  title: block.content['caption'] as String? ?? 'Video Preview',
                )
              : Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final XFile? file = await picker.pickMedia();
                  if (file != null) {
                    final publicUrl = await _uploadXFile(file);
                    if (publicUrl != null) {
                      _markChanged();
                      _clearError(block.id);
                      setState(() {
                        final ext = file.name.split('.').last.toLowerCase();
                        final isVideo = ext == 'mp4' ||
                            ext == 'mov' ||
                            ext == 'avi';
                        block.content['url'] = publicUrl;
                        block.content['type'] = isVideo ? 'video' : 'image';
                      });
                    }
                  }
                },
                icon: const Icon(Icons.upload),
                label: Text(url.isEmpty ? 'Upload Media' : 'Replace Media'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(
            labelText: 'Media Caption (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildTestBlockEditor(LessonBlock block, int index) {
    if (!_questionControllers.containsKey(block.id)) {
      _questionControllers[block.id] =
          TextEditingController(text: block.content['question'] ?? '')
            ..addListener(() {
              _markChanged();
              _clearError(block.id);
            });
    }
    final qCtrl = _questionControllers[block.id]!;

    if (!_explanationControllers.containsKey(block.id)) {
      _explanationControllers[block.id] =
          TextEditingController(text: block.content['explanation'] ?? '')
            ..addListener(() {
              _markChanged();
              _clearError(block.id);
            });
    }
    final expCtrl = _explanationControllers[block.id]!;

    final isMultipleChoice = block.content['is_multiple_choice'] as bool? ?? false;
    
    if (block.content['options'] == null) {
      block.content['options'] = <dynamic>[];
    }
    final List<dynamic> options = block.content['options'] as List<dynamic>;

    if (!_optionControllers.containsKey(block.id)) {
      _optionControllers[block.id] = options
          .map((opt) => TextEditingController(text: (opt as Map)['text'] ?? '')
            ..addListener(() {
              _markChanged();
              _clearError(block.id);
            }))
          .toList();
    }
    final optCtrls = _optionControllers[block.id]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: qCtrl,
          decoration: const InputDecoration(
            labelText: 'Question Text',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: expCtrl,
          decoration: const InputDecoration(
            labelText: 'Explanation (optional)',
            hintText: 'Provide context or explanation for the correct answer',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
        ),
        const SizedBox(height: 16),
        const Text(
          'Answers (Check the correct option):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...List.generate(optCtrls.length, (optIdx) {
          final opt = options[optIdx] as Map;
          final isCorrect = opt['is_correct'] as bool? ?? false;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                if (isMultipleChoice)
                  Checkbox(
                    value: isCorrect,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) {
                      _markChanged();
                      _clearError(block.id);
                      setState(() {
                        opt['is_correct'] = val == true;
                      });
                    },
                  )
                else
                  Radio<int>(
                    value: optIdx,
                    groupValue: options.indexWhere((o) => (o as Map)['is_correct'] == true),
                    activeColor: Colors.deepPurple,
                    onChanged: (val) {
                      _markChanged();
                      _clearError(block.id);
                      setState(() {
                        for (int k = 0; k < options.length; k++) {
                          (options[k] as Map)['is_correct'] = k == val;
                        }
                      });
                    },
                  ),
                Expanded(
                  child: TextField(
                    controller: optCtrls[optIdx],
                    decoration: InputDecoration(
                      hintText: 'Option ${optIdx + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _markChanged();
                    _clearError(block.id);
                    setState(() {
                      options.removeAt(optIdx);
                      optCtrls[optIdx].dispose();
                      optCtrls.removeAt(optIdx);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _markChanged();
              _clearError(block.id);
              setState(() {
                options.add({'text': '', 'is_correct': false});
                optCtrls.add(TextEditingController()..addListener(() {
                  _markChanged();
                  _clearError(block.id);
                }));
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Option'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Multiple Choice (Checkbox)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Switch(
              value: isMultipleChoice,
              activeThumbColor: Colors.deepPurple,
              onChanged: (val) {
                _markChanged();
                _clearError(block.id);
                setState(() {
                  block.content['is_multiple_choice'] = val;
                  if (!val) {
                    // Reset to single correct answer
                    bool foundCorrect = false;
                    for (var opt in options) {
                      final optMap = opt as Map;
                      if (optMap['is_correct'] == true) {
                        if (foundCorrect) {
                          optMap['is_correct'] = false;
                        } else {
                          foundCorrect = true;
                        }
                      }
                    }
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileBlockEditor(LessonBlock block, int index) {
    final url = block.content['url'] as String? ?? '';
    final fileName = block.content['name'] as String? ?? '';
    final fileSize = block.content['size'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (fileSize.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(fileSize,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final file = result.files.single;
                    final publicUrl = await _uploadFile(file);
                    if (publicUrl != null) {
                      _markChanged();
                      _clearError(block.id);
                      setState(() {
                        block.content['url'] = publicUrl;
                        block.content['name'] = file.name;
                        block.content['size'] =
                            '${(file.size / 1024).toStringAsFixed(1)} KB';
                      });
                    }
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: Text(url.isEmpty ? 'Upload File' : 'Replace File'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to exit without saving?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        if (!context.mounted) return;
        if (confirm == true) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.pageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Slide',
              onPressed: _saveChanges,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isSaving
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Saving elements...',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (_isTooLong) _buildWarningBanner(),
                      Expanded(
                        child: _blocks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_to_photos_rounded,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Slide is empty',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                                      child: Text(
                                        'Add content blocks below to structure this slide.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, top: 16, bottom: 88),
                                itemCount: _blocks.length,
                                itemBuilder: (context, index) {
                                  return _buildBlockEditor(_blocks[index], index);
                                },
                              ),
                      ),
                    ],
                  ),
        // Sticky insertion bar wrapped in SafeArea
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _addBlock('text'),
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Text'),
                ),
                TextButton.icon(
                  onPressed: () => _addBlock('media'),
                  icon: const Icon(Icons.image),
                  label: const Text('Media'),
                ),
                TextButton.icon(
                  onPressed: () => _addBlock('test'),
                  icon: const Icon(Icons.check_box_outlined),
                  label: const Text('Test'),
                ),
                TextButton.icon(
                  onPressed: () => _addBlock('file'),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('File'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
