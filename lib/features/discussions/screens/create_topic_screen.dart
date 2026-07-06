import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/models/discussion_models.dart';
import '../../learn/models/lesson_models.dart';

class PendingAttachment {
  final String? localPath;
  final String name;
  final String type; // 'image', 'video', 'gif', 'link', 'file'
  final String? linkUrl;
  final String? remoteUrl;

  PendingAttachment({
    this.localPath,
    required this.name,
    required this.type,
    this.linkUrl,
    this.remoteUrl,
  });
}

class CreateTopicScreen extends StatefulWidget {
  final DiscussionTopic? topic;
  final String? courseId;
  final String? chapterId;
  final String? subChapterId;
  final String? pageId;

  const CreateTopicScreen({
    super.key,
    this.topic,
    this.courseId,
    this.chapterId,
    this.subChapterId,
    this.pageId,
  });

  @override
  State<CreateTopicScreen> createState() => _CreateTopicScreenState();
}

class _CreateTopicScreenState extends State<CreateTopicScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingCourses = true;
  bool _isLoadingMetadata = false;
  List<LessonCourse> _courses = [];
  String? _selectedCourseId;

  // Linked metadata titles for read-only preview
  String? _metaCourseTitle;
  String? _metaChapterTitle;
  String? _metaSubChapterTitle;
  int? _metaPagePosition;

  String? _resolvedCourseId;
  String? _resolvedChapterId;
  String? _resolvedSubChapterId;

  // List of pending attachments
  final List<PendingAttachment> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
    if (widget.topic != null) {
      _titleController.text = widget.topic!.title;
      _contentController.text = widget.topic!.content;
      for (var att in widget.topic!.attachments) {
        _pendingAttachments.add(PendingAttachment(
          name: att.name,
          type: att.type,
          linkUrl: att.type == 'link' ? att.url : null,
          remoteUrl: att.type != 'link' ? att.url : null,
        ));
      }
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
      if (widget.pageId != null) {
        _isLoadingMetadata = true;
      }
    });

    try {
      final courses = await LessonRepository().getCourses();
      _courses = courses;
      _isLoadingCourses = false;
      if (widget.topic != null) {
        _selectedCourseId = widget.topic!.courseId;
      } else if (widget.courseId != null) {
        _selectedCourseId = widget.courseId;
      }
      setState(() {});
    } catch (_) {
      setState(() => _isLoadingCourses = false);
    }

    if (widget.pageId != null) {
      try {
        final meta = await LessonRepository().getPageMetadata(widget.pageId!);
        if (meta != null) {
          final subData = meta['lesson_sub_chapters'] as Map<String, dynamic>?;
          final chapData = subData?['lesson_chapters'] as Map<String, dynamic>?;
          final courseData = chapData?['lesson_courses'] as Map<String, dynamic>?;
          setState(() {
            _metaCourseTitle = courseData?['title'] as String?;
            _metaChapterTitle = chapData?['title'] as String?;
            _metaSubChapterTitle = subData?['title'] as String?;
            _metaPagePosition = meta['position'] as int?;

            _resolvedCourseId = chapData?['course_id'] as String?;
            _resolvedChapterId = subData?['chapter_id'] as String?;
            _resolvedSubChapterId = meta['sub_chapter_id'] as String?;
          });
        }
      } catch (_) {}
      setState(() => _isLoadingMetadata = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _getMediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'].contains(ext)) {
      return 'image';
    }
    if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'flv'].contains(ext)) {
      return 'video';
    }
    return 'file';
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final List<XFile> pickedMedia = await picker.pickMultipleMedia();
      if (pickedMedia.isNotEmpty) {
        setState(() {
          for (var file in pickedMedia) {
            final type = _getMediaType(file.name);
            _pendingAttachments.add(PendingAttachment(
              localPath: file.path,
              name: file.name,
              type: type,
            ));
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error picking media: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _pendingAttachments.add(PendingAttachment(
            localPath: pickedFile.path,
            name: pickedFile.name,
            type: 'image',
          ));
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  Future<void> _pickGeneralFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.paths.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              _pendingAttachments.add(PendingAttachment(
                localPath: file.path,
                name: file.name,
                type: 'file',
              ));
            }
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _pendingAttachments.add(PendingAttachment(
            localPath: pickedFile.path,
            name: pickedFile.name,
            type: 'video',
          ));
        });
      }
    } catch (e) {
      _showSnackBar('Error recording video: $e');
    }
  }

  void _showCameraMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.deepPurple),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Colors.deepPurple),
                title: const Text('Record Video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _recordVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.deepPurple),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.deepPurple),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCameraMenu();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded, color: Colors.deepPurple),
                title: const Text('File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickGeneralFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = context.read<DiscussionRepository>();
      final List<DiscussionAttachment> uploadedAttachments = [];

      // Loop and upload files asynchronously
      for (var pending in _pendingAttachments) {
        String? finalUrl;
        if (pending.remoteUrl != null) {
          finalUrl = pending.remoteUrl;
        } else if (pending.localPath != null) {
          finalUrl = await repo.uploadAttachment(pending.localPath!, pending.name);
        } else if (pending.linkUrl != null) {
          finalUrl = pending.linkUrl;
        }

        if (finalUrl != null) {
          uploadedAttachments.add(DiscussionAttachment(
            url: finalUrl,
            name: pending.name,
            type: pending.type,
          ));
        }
      }

      if (_isLoadingMetadata) {
        _showSnackBar('Still loading lesson metadata, please wait...');
        setState(() => _isLoading = false);
        return;
      }

      final String finalTag;
      if (widget.pageId != null && _metaCourseTitle != null) {
        finalTag = _metaCourseTitle!;
      } else if (_selectedCourseId != null) {
        final match = _courses.firstWhere(
          (c) => c.id == _selectedCourseId,
          orElse: () => LessonCourse(id: '', title: widget.topic?.tag ?? 'General'),
        );
        finalTag = match.title;
      } else {
        finalTag = 'General';
      }

      if (widget.topic != null) {
        await repo.updateTopic(
          topicId: widget.topic!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          tag: finalTag,
          attachments: uploadedAttachments,
          courseId: _resolvedCourseId ?? _selectedCourseId,
        );
      } else {
        await repo.createTopic(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          tag: finalTag,
          attachments: uploadedAttachments,
          courseId: _resolvedCourseId ?? _selectedCourseId,
          chapterId: _resolvedChapterId ?? widget.chapterId,
          subChapterId: _resolvedSubChapterId ?? widget.subChapterId,
          pageId: widget.pageId,
        );
      }

      if (mounted) {
        _showSnackBar(widget.topic != null
            ? 'Discussion topic updated successfully!'
            : 'Discussion topic created successfully!');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to save topic: $e');
      }
    }
  }

  Widget _buildAttachmentsPreviewList() {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Attachments (${_pendingAttachments.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pendingAttachments.length,
          itemBuilder: (context, index) {
            final pending = _pendingAttachments[index];
            IconData icon;
            Color color;

            switch (pending.type) {
              case 'image':
                icon = Icons.image;
                color = Colors.green;
                break;
              case 'video':
                icon = Icons.video_collection;
                color = Colors.red;
                break;
              case 'link':
                icon = Icons.link;
                color = Colors.blue;
                break;
              default:
                icon = Icons.insert_drive_file;
                color = Colors.orange;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pending.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _pendingAttachments.removeAt(index);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic != null ? 'Edit Discussion' : 'New Discussion'),
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
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Topic Title',
                        hintText: 'What is your discussion about?',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please enter a title'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (widget.pageId != null) ...[
                      _isLoadingMetadata
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.menu_book_rounded, size: 16, color: Colors.blue.shade800),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Linked Lesson Page Context',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  _buildMetaRow('Lesson', _metaCourseTitle ?? 'Loading...'),
                                  const SizedBox(height: 8),
                                  _buildMetaRow('Chapter', _metaChapterTitle ?? 'Loading...'),
                                  const SizedBox(height: 8),
                                  _buildMetaRow('Sub-Chapter', _metaSubChapterTitle ?? 'Loading...'),
                                  const SizedBox(height: 8),
                                  _buildMetaRow('Current Slide', 'Slide ${(_metaPagePosition ?? 0) + 1}'),
                                ],
                              ),
                            ),
                    ] else ...[
                      DropdownButtonFormField<String?>(
                        decoration: InputDecoration(
                          labelText: _isLoadingCourses ? 'Loading lessons...' : 'Associate Lesson',
                        ),
                        value: _selectedCourseId,
                        onChanged: (widget.courseId != null || (widget.topic != null && widget.topic!.courseId != null))
                            ? null
                            : (val) {
                                setState(() => _selectedCourseId = val);
                              },
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('General Discussions (No Lesson)'),
                          ),
                          ..._courses.map((course) {
                            return DropdownMenuItem<String?>(
                              value: course.id,
                              child: Text(course.title),
                            );
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Body Content',
                        hintText: 'Provide details, ask questions, or share thoughts...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 6,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please enter details'
                          : null,
                    ),
                    _buildAttachmentsPreviewList(),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: _showAttachmentMenu,
                      icon: const Icon(Icons.add_to_photos_rounded),
                      label: const Text('Add Attachment'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(widget.topic != null ? 'Save Changes' : 'Post Topic'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
