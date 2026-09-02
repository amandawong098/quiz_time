import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/ai_quiz_service.dart';
import '../../../core/services/ai_generation_manager.dart';
import '../../../core/widgets/gemini_model_selector_sheet.dart';

class AILessonGeneratorScreen extends StatefulWidget {
  const AILessonGeneratorScreen({super.key});

  @override
  State<AILessonGeneratorScreen> createState() =>
      _AILessonGeneratorScreenState();
}

class _AILessonGeneratorScreenState extends State<AILessonGeneratorScreen> {
  final _promptController = TextEditingController();
  final _focusNode = FocusNode();

  // Lesson Generation options
  String _selectedAudience = 'Intermediate'; // Beginner, Intermediate, Advanced
  final bool _generateCoverImage = true;
  String _selectedModel = 'gemini-1.5-flash';

  // File upload state (supports multi-file selection)
  final List<PlatformFile> _selectedFiles = [];
  bool _isUploadingFile = false;

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pptx':
      case 'ppt':
        return Icons.slideshow_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return Icons.description_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
      case 'flac':
        return Icons.audiotrack_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  // API Key state
  bool _hasApiKey = false;

  static const int _maxFileSizeBytes = 15 * 1024 * 1024; // 15MB

  final Map<String, String> _modelDisplayNames = {
    'gemini-3.6-flash': 'Gemini 3.6 Flash (Next-Gen)',
    'gemini-3.0-flash': 'Gemini 3.0 Flash',
    'gemini-2.0-flash': 'Gemini 2.0 Flash',
    'gemini-2.0-flash-exp': 'Gemini 2.0 Flash (Exp)',
    'gemini-2.0-flash-thinking-exp': 'Gemini 2.0 Flash Thinking',
    'gemini-2.0-pro-exp': 'Gemini 2.0 Pro',
    'gemini-1.5-flash': 'Gemini 1.5 Flash',
    'gemini-1.5-flash-latest': 'Gemini 1.5 Flash (Latest)',
    'gemini-1.5-pro': 'Gemini 1.5 Pro',
    'gemini-1.5-pro-latest': 'Gemini 1.5 Pro (Latest)',
  };

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
    _loadSelectedModel();
    AIGenerationManager().addListener(_onAIManagerUpdated);
  }

  @override
  void dispose() {
    AIGenerationManager().removeListener(_onAIManagerUpdated);
    _promptController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAIManagerUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkApiKeyStatus() async {
    final key = await AIQuizService.getApiKey();
    if (mounted) {
      setState(() {
        _hasApiKey = key != null && key.isNotEmpty;
      });
    }
  }

  Future<void> _loadSelectedModel() async {
    final model = await AIQuizService.getSelectedModel();
    if (mounted) {
      setState(() {
        _selectedModel = model;
      });
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isUploadingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<PlatformFile> validFiles = [];
        for (final file in result.files) {
          if (file.size > _maxFileSizeBytes) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'File "${file.name}" exceeds maximum allowed size of 15MB.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          } else {
            Uint8List? bytes = file.bytes;
            if (bytes == null && file.path != null) {
              bytes = await File(file.path!).readAsBytes();
            }
            final readyFile = PlatformFile(
              name: file.name,
              size: file.size,
              bytes: bytes,
              path: file.path,
            );
            final alreadyExists = _selectedFiles.any(
              (f) => f.name == file.name && f.size == file.size,
            );
            if (!alreadyExists) {
              validFiles.add(readyFile);
            }
          }
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      if (index >= 0 && index < _selectedFiles.length) {
        _selectedFiles.removeAt(index);
      }
    });
  }

  String _getModelDisplayName(String modelId) {
    if (_modelDisplayNames.containsKey(modelId)) {
      return _modelDisplayNames[modelId]!;
    }
    return modelId
        .replaceAll('gemini-', 'Gemini ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Future<void> _showModelSelectorSheet() async {
    final selected = await showGeminiModelSelectorSheet(
      context: context,
      currentModel: _selectedModel,
      onApiKeyRequested: _showApiKeyDialog,
    );
    if (selected != null && mounted) {
      setState(() => _selectedModel = selected);
    }
  }

  Future<void> _showApiKeyDialog() async {
    final currentKey = await AIQuizService.getApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API Key from Google AI Studio.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final uri =
                    Uri.parse('https://aistudio.google.com/app/apikey');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                'Get a free Gemini API Key from Google AI Studio ↗',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (currentKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await AIQuizService.clearApiKey();
                await _checkApiKeyStatus();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Clear Key',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = controller.text.trim();
              if (newKey.isNotEmpty) {
                await AIQuizService.saveApiKey(newKey);
                await _checkApiKeyStatus();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  Future<void> _startLessonGeneration() async {
    final promptText = _promptController.text.trim();
    final hasFiles = _selectedFiles.isNotEmpty;

    if (promptText.isEmpty && !hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please enter a lesson topic or attach syllabus/notes.'),
        ),
      );
      return;
    }

    final apiKey = await AIQuizService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      await _showApiKeyDialog();
      final updatedKey = await AIQuizService.getApiKey();
      if (updatedKey == null || updatedKey.isEmpty) {
        return;
      }
    }

    if (!mounted) return;

    // Detect if multiple files or lengthy files were uploaded
    final bool isMultiFile = _selectedFiles.length > 1;
    final int totalBytes = _selectedFiles.fold(0, (acc, f) => acc + f.size);
    final bool isLengthyContent = isMultiFile || totalBytes > 3 * 1024 * 1024;

    if (isLengthyContent) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.auto_stories_rounded, color: Colors.deepPurple, size: 36),
          title: const Text(
            'Multi-Chapter Content Detected',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isMultiFile
                ? 'You have attached ${_selectedFiles.length} files. Because extensive study materials were provided, the AI may structure this course across multiple chapters or extended modules to cover the topics thoroughly.\n\nWould you like to proceed with generation, or go back to adjust your files?'
                : 'Your uploaded document contains extensive content. The AI may generate multiple chapters or in-depth modules to ensure comprehensive coverage.\n\nWould you like to proceed with generation, or go back to adjust your files?',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Adjust Files', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Proceed & Generate'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        return;
      }
    }

    if (!mounted) return;

    // Launch background lesson generation
    await AIGenerationManager().startLessonGeneration(
      context: context,
      prompt: promptText,
      filesBytes: _selectedFiles.map((f) => f.bytes!).toList(),
      filesNames: _selectedFiles.map((f) => f.name).toList(),
      lessonScope: 'Auto',
      audience: _selectedAudience,
      generateCover: _generateCoverImage,
      generateInSlideImages: hasFiles,
      modelName: _selectedModel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final aiManager = AIGenerationManager();
    final currentTask = aiManager.currentTask;
    final isCurrentLessonTask =
        currentTask != null && currentTask.taskType == AITaskType.lesson;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Lesson Generator',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.vpn_key_rounded),
                if (!_hasApiKey)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Gemini API Key Settings',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: isCurrentLessonTask &&
              currentTask.status == AITaskStatus.generating
          ? _buildActiveTaskView(theme, currentTask)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Completed task card (if any recent finished task)
                  if (isCurrentLessonTask &&
                      currentTask.status == AITaskStatus.completed)
                    _buildCompletedTaskBanner(currentTask),

                  // Failed task banner (if any recent failed task)
                  if (isCurrentLessonTask &&
                      currentTask.status == AITaskStatus.failed)
                    _buildFailedTaskBanner(currentTask),
                  
                  // Recommendation guidance banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Recommendation: Generating 1 chapter at a time provides the deepest explanations, figures, and interactive checkpoints.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unified Prompt + Attachment Box (Antigravity Style)
                  _buildUnifiedPromptContainer(isDark, theme),

                  const SizedBox(height: 16),

                  // Configuration section (Scope, Diagrams, Audience)
                  _buildConfigurationCard(theme, primaryColor),

                  const SizedBox(height: 28),

                  // Main Action Button
                  ElevatedButton.icon(
                    onPressed: _startLessonGeneration,
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text(
                      'Generate Lesson with AI',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  // AI mistake disclaimer
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'AI can make mistakes. Please verify important educational information.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildUnifiedPromptContainer(bool isDark, ThemeData theme) {
    final containerBg =
        isDark ? const Color(0xFF1E1F24) : const Color(0xFFF3F4F8);
    final borderColor =
        isDark ? const Color(0xFF33353D) : const Color(0xFFE2E4EB);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _promptController,
            focusNode: _focusNode,
            maxLines: 5,
            minLines: 2,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText:
                  'Type course topic, syllabus, or attach any study file (PPTX, PDF, Audio, Images, Docs)...',
              hintStyle: TextStyle(
                color:
                    isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_selectedFiles.length, (idx) {
                final file = _selectedFiles[idx];
                return Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 64,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.deepPurple.shade900.withValues(alpha: 0.5)
                        : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFileIcon(file.name),
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${_formatFileSize(file.size)})',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _removeSelectedFile(idx),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              InkWell(
                onTap: _isUploadingFile ? null : _pickFile,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isUploadingFile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                ),
              ),
              const SizedBox(width: 8),

              InkWell(
                onTap: _showModelSelectorSheet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getModelDisplayName(_selectedModel),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              InkWell(
                onTap: _startLessonGeneration,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard(ThemeData theme, Color primaryColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded,
                    size: 20, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'Lesson Scope & Structure',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),

            // Adaptive Curriculum Structure Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.deepPurple.shade900.withValues(alpha: 0.3)
                    : Colors.deepPurple.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adaptive Modules & Slide Sizing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Modules and slides are automatically determined by AI based on the complexity, syllabus breadth, and length of your topic.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Audience / Difficulty
            const Text(
              'Technical Depth / Audience',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                'Beginner / Intro',
                'Intermediate / College',
                'Advanced / Expert'
              ].map((lvl) {
                final isSelected = _selectedAudience == lvl;
                return ChoiceChip(
                  label: Text(lvl),
                  selected: isSelected,
                  selectedColor: Colors.deepPurple.shade100,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAudience = lvl);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Authentic In-Slide Visuals Notice Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : Colors.deepPurple.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Authentic In-Slide Visuals',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '• From Attachments: Authentic figures, charts, and diagrams from your attached file (.pptx, .pdf, .docx, images) are automatically extracted and embedded into slides.\n'
                          '• Prompt-Only: Lessons generated from text prompts focus on clean, structured conceptual text, formulas, and interactive checkpoints.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
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

  Widget _buildActiveTaskView(ThemeData theme, AIGenerationTask task) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade300,
                    Colors.deepPurple.shade700,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Colors.amberAccent,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Generating Lesson & Slides...',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.prompt.isNotEmpty
                  ? task.prompt
                  : (task.fileName ?? 'Course syllabus'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              task.statusMessage,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFEDE7F6),
              ),
            ),
            const SizedBox(height: 36),

            // Run in Background Button
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'AI Lesson generation running in background. You will find it in My Lessons when complete!',
                    ),
                    duration: Duration(seconds: 4),
                  ),
                );
                context.pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Run in Background & Leave'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTaskBanner(AIGenerationTask task) {
    return Card(
      color: Colors.green.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: ListTile(
        leading: task.generatedCoverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  task.generatedCoverUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white, size: 20),
                  ),
                ),
              )
            : const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white, size: 20),
              ),
        title: Text(
          'Course Ready: ${task.generatedTitle ?? "New Course"}',
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        subtitle: const Text('Saved to your library in My Lessons.'),
        trailing: ElevatedButton(
          onPressed: () {
            context.go('/my-lessons');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('View Lessons'),
        ),
      ),
    );
  }

  Widget _buildFailedTaskBanner(AIGenerationTask task) {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          child: Icon(Icons.error_outline, color: Colors.white, size: 20),
        ),
        title: const Text(
          'Generation Failed',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        subtitle: Text(
          task.error ?? 'Please check your API key or network connection.',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => AIGenerationManager().dismissCurrentTask(),
        ),
      ),
    );
  }
}
