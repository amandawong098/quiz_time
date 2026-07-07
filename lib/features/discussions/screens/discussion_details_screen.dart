import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/models/discussion_models.dart';
import './create_topic_screen.dart'; // Reuse PendingAttachment class
import '../../../core/widgets/in_app_video_player.dart';
import '../../../core/widgets/video_preview_widget.dart';

class DiscussionDetailsScreen extends StatefulWidget {
  final String topicId;
  const DiscussionDetailsScreen({super.key, required this.topicId});

  @override
  State<DiscussionDetailsScreen> createState() => _DiscussionDetailsScreenState();
}

class _DiscussionDetailsScreenState extends State<DiscussionDetailsScreen> {
  bool _isLoading = true;
  DiscussionTopic? _topic;
  List<DiscussionReply> _replies = [];
  String _sortBy = 'upvotes';

  final _replyController = TextEditingController();
  bool _isPostingReply = false;

  // Comment pending attachments list
  final List<PendingAttachment> _commentAttachments = [];

  DiscussionReply? _replyingTo;
  DiscussionReply? _editingReply;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      final repo = context.read<DiscussionRepository>();
      final topic = await repo.getTopicDetails(widget.topicId);
      final replies = await repo.getReplies(widget.topicId);

      if (mounted) {
        setState(() {
          _topic = topic;
          _replies = replies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading thread: $e');
      }
    }
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null) return;
    try {
      final Uri url = Uri.parse(urlString);
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        final launchedFallback = await launchUrl(url);
        if (!launchedFallback) {
          _showSnackBar('Could not launch attachment url');
        }
      }
    } catch (e) {
      try {
        final Uri url = Uri.parse(urlString);
        final launched = await launchUrl(url);
        if (!launched) {
          _showSnackBar('Could not launch attachment url');
        }
      } catch (e2) {
        _showSnackBar('Could not launch attachment url: $e2');
      }
    }
  }

  Future<void> _voteTopic(int voteType) async {
    if (_topic == null) return;
    try {
      final repo = context.read<DiscussionRepository>();
      await repo.voteTopic(_topic!.id, voteType);
      await _loadDetails();
    } catch (e) {
      _showSnackBar('Vote failed: $e');
    }
  }

  Future<void> _voteReply(String replyId, int voteType) async {
    try {
      final repo = context.read<DiscussionRepository>();
      await repo.voteReply(replyId, voteType);
      await _loadDetails();
    } catch (e) {
      _showSnackBar('Vote failed: $e');
    }
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
            _commentAttachments.add(PendingAttachment(
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
      final XFile? pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _commentAttachments.add(PendingAttachment(
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
              _commentAttachments.add(PendingAttachment(
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
          _commentAttachments.add(PendingAttachment(
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

  final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+|[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-z]{2,}(?:\/[^\s]*)?)',
    caseSensitive: false,
  );

  Widget _buildTextWithLinks(String text, BuildContext context, {double fontSize = 13}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? Colors.deepPurple.shade300 : Colors.deepPurple;

    final matches = _urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.4,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      );
    }

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ));
      }

      final urlText = match.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () {
            var uriStr = urlText;
            if (!uriStr.startsWith('http://') && !uriStr.startsWith('https://')) {
              uriStr = 'https://$uriStr';
            }
            _launchUrl(uriStr);
          },
          child: Text(
            urlText,
            style: TextStyle(
              color: linkColor,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
              fontSize: fontSize,
            ),
          ),
        ),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: fontSize,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, height: 1.4),
        children: spans,
      ),
    );
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty && _commentAttachments.isEmpty) return;

    setState(() => _isPostingReply = true);

    try {
      final repo = context.read<DiscussionRepository>();
      final List<DiscussionAttachment> uploadedAttachments = [];

      // Loop and upload comment files
      for (var pending in _commentAttachments) {
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

      if (_editingReply != null) {
        // Edit existing reply
        await repo.updateReply(
          replyId: _editingReply!.id,
          content: text,
          attachments: uploadedAttachments,
        );
      } else {
        // Create new reply (optionally threaded)
        String? parentId;
        String? replyToId;

        if (_replyingTo != null) {
          parentId = _replyingTo!.id;
          replyToId = _replyingTo!.id;
        }

        await repo.createReply(
          topicId: widget.topicId,
          content: text,
          attachments: uploadedAttachments,
          parentId: parentId,
          replyToId: replyToId,
        );
      }

      _replyController.clear();
      setState(() {
        _commentAttachments.clear();
        _replyingTo = null;
        _editingReply = null;
        _isPostingReply = false;
      });

      await _loadDetails();
    } catch (e) {
      setState(() => _isPostingReply = false);
      _showSnackBar('Failed to save comment: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildAttachmentsList(List<DiscussionAttachment> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: attachments.map((att) {
        if (att.type == 'image') {
          return Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(
                att.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Failed to load attachment image'),
                ),
              ),
            ),
          );
        }

        if (att.type == 'video') {
          return VideoPreviewWidget(
            videoUrl: att.url,
            title: att.name,
          );
        }

        IconData icon;
        Color color;

        switch (att.type) {
          case 'link':
            icon = Icons.link_rounded;
            color = Colors.blue;
            break;
          default:
            icon = Icons.insert_drive_file_rounded;
            color = Colors.orange;
        }

        final isVideo = att.type == 'video';
        final isLink = att.type == 'link';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(top: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Icon(icon, color: color, size: 24),
            title: Text(
              att.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isVideo
                  ? 'Play Video'
                  : (isLink ? 'Launch Hyperlink' : 'Download Attachment'),
              style: const TextStyle(fontSize: 10),
            ),
            trailing: isVideo
                ? const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.deepPurple)
                : const Icon(Icons.download, size: 18, color: Colors.grey),
            onTap: () {
              if (isVideo) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InAppVideoPlayerScreen(
                      videoUrl: att.url,
                      title: att.name,
                    ),
                  ),
                );
              } else {
                _launchUrl(att.url);
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommentPreviewBadgeList() {
    if (_commentAttachments.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        border: Border(top: BorderSide(color: Colors.deepPurple.shade100)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _commentAttachments.length,
        itemBuilder: (context, index) {
          final pending = _commentAttachments[index];

          if (pending.type == 'image') {
            return Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: pending.localPath != null
                        ? Image.file(
                            File(pending.localPath!),
                            fit: BoxFit.cover,
                          )
                        : (pending.remoteUrl != null
                            ? Image.network(
                                pending.remoteUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image, color: Colors.grey),
                              )),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _commentAttachments.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }

          IconData icon;

          switch (pending.type) {
            case 'video':
              icon = Icons.video_collection;
              break;
            case 'link':
              icon = Icons.link;
              break;
            default:
              icon = Icons.insert_drive_file;
          }

          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.deepPurple, size: 16),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    pending.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      _commentAttachments.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVotingWidget({required int score, required int userVote, required VoidCallback onUpvote, required VoidCallback onDownvote}) {
    final upvoted = userVote == 1;
    final downvoted = userVote == -1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_upward_rounded,
            color: upvoted ? Colors.deepPurple : Colors.grey.shade400,
            size: 26,
          ),
          onPressed: onUpvote,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(height: 4),
        Text(
          score.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: upvoted
                ? Colors.deepPurple
                : (downvoted ? Colors.red : Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 4),
        IconButton(
          icon: Icon(
            Icons.arrow_downward_rounded,
            color: downvoted ? Colors.red : Colors.grey.shade400,
            size: 26,
          ),
          onPressed: onDownvote,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_topic == null) {
      return const Scaffold(body: Center(child: Text('Discussion thread not found')));
    }

    final treeRoots = _buildCommentTree(_replies);
    final displayDate = _topic!.updatedAt ?? _topic!.createdAt;
    final dateStr = '${displayDate.day}/${displayDate.month}/${displayDate.year}';
    final editedStr = _topic!.updatedAt != null ? ' (edited)' : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Thread Title & Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upvotes arrows
                      _buildVotingWidget(
                        score: _topic!.score,
                        userVote: _topic!.userVoteType,
                        onUpvote: () => _voteTopic(1),
                        onDownvote: () => _voteTopic(-1),
                      ),
                      const SizedBox(width: 16),
                      // Core info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_topic!.courseId != null) ...[
                              InkWell(
                                onTap: () {
                                  if (_topic!.subChapterId != null) {
                                    context.push('/lesson-player?subChapterId=${_topic!.subChapterId}&isPreview=true&initialPageId=${_topic!.pageId}');
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.deepPurple.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.menu_book_rounded, size: 12, color: Colors.deepPurple),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Builder(
                                          builder: (context) {
                                            final slideNo = (_topic!.pagePosition ?? 0) + 1;
                                            return Text(
                                              '${_topic!.courseTitle ?? "Lesson"} > ${_topic!.chapterTitle ?? ""} > ${_topic!.subChapterTitle ?? ""} > Slide $slideNo',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          }
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (_topic!.quizId != null) ...[
                              InkWell(
                                onTap: () {
                                  String path = '/quiz/${_topic!.quizId}/take?preview=true';
                                  if (_topic!.questionId != null) {
                                    path += '&initialQuestionId=${_topic!.questionId}';
                                  }
                                  context.push(path);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.deepPurple.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.assignment_turned_in_rounded, size: 12, color: Colors.deepPurple),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Builder(
                                          builder: (context) {
                                            final label = _topic!.questionId != null
                                                ? '${_topic!.quizTitle ?? "Quiz"} > Question ${(_topic!.questionOrderIndex ?? 0) + 1}'
                                                : (_topic!.quizTitle ?? "Quiz");
                                            return Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          }
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _topic!.tag.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _topic!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.deepPurple.shade100,
                                  backgroundImage: _topic!.authorAvatarUrl != null
                                      ? NetworkImage(_topic!.authorAvatarUrl!)
                                      : null,
                                  child: _topic!.authorAvatarUrl == null
                                      ? const Icon(Icons.person, size: 12)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _topic!.authorName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  '$dateStr$editedStr',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Content Description
                  _buildTextWithLinks(_topic!.content, context, fontSize: 15),
                  _buildAttachmentsList(_topic!.attachments),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Replies (${_replies.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          icon: const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.sort_rounded, size: 16, color: Colors.deepPurple),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.deepPurple.shade200
                                : Colors.deepPurple.shade700,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text('Newest'),
                            ),
                            DropdownMenuItem(
                              value: 'upvotes',
                              child: Text('Top Upvotes'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sortBy = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (treeRoots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No replies yet. Be the first to start the discussion!',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._buildCommentTreeWidgets(treeRoots, 0),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          // Reply input bar
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null || _editingReply != null)
                    Container(
                      color: Colors.deepPurple.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _replyingTo != null ? Icons.reply : Icons.edit,
                            color: Colors.deepPurple,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _replyingTo != null
                                  ? 'Replying to @${_replyingTo!.authorName}'
                                  : 'Editing your comment',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                          GestureDetector(
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                            onTap: () {
                              setState(() {
                                _replyingTo = null;
                                _editingReply = null;
                                _replyController.clear();
                                _commentAttachments.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  _buildCommentPreviewBadgeList(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.deepPurple, size: 28),
                          onPressed: _showAttachmentMenu,
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _replyController,
                              decoration: const InputDecoration(
                                hintText: 'Write a reply...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              maxLines: null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isPostingReply
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send, color: Colors.deepPurple),
                                onPressed: _submitReply,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CommentNode> _buildCommentTree(List<DiscussionReply> replies) {
    final Map<String, CommentNode> nodeMap = {
      for (var r in replies) r.id: CommentNode(r)
    };

    final List<CommentNode> roots = [];

    for (var node in nodeMap.values) {
      final parentId = node.reply.parentId;
      if (parentId == null || !nodeMap.containsKey(parentId)) {
        roots.add(node);
      } else {
        nodeMap[parentId]!.children.add(node);
      }
    }

    if (_sortBy == 'upvotes') {
      roots.sort((a, b) {
        final scoreCompare = b.reply.score.compareTo(a.reply.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.reply.createdAt.compareTo(a.reply.createdAt);
      });
    } else {
      roots.sort((a, b) => b.reply.createdAt.compareTo(a.reply.createdAt));
    }
    for (var node in nodeMap.values) {
      node.children.sort((a, b) => a.reply.createdAt.compareTo(b.reply.createdAt));
    }

    return roots;
  }

  List<Widget> _buildCommentTreeWidgets(List<CommentNode> nodes, int depth) {
    List<Widget> widgets = [];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    for (var node in nodes) {
      widgets.add(
        _buildReplyCard(node.reply, depth: depth, currentUserId: currentUserId),
      );
      if (node.children.isNotEmpty) {
        widgets.addAll(
          _buildCommentTreeWidgets(node.children, depth + 1),
        );
      }
    }
    return widgets;
  }

  Widget _buildReplyCard(
    DiscussionReply reply, {
    required int depth,
    required String? currentUserId,
  }) {
    final double leftMargin = (depth > 3 ? 3 : depth) * 16.0;
    final backgroundColor = _getBackgroundColor(context, depth);
    final borderColor = _getBorderColor(context, depth);

    final displayDate = reply.updatedAt ?? reply.createdAt;
    final dateStr = '${displayDate.day}/${displayDate.month}/${displayDate.year}';
    final editedStr = reply.updatedAt != null ? ' (edited)' : '';

    final cardContent = Card(
      elevation: 0,
      margin: EdgeInsets.only(left: leftMargin, bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.deepPurple.shade100,
                  backgroundImage: reply.authorAvatarUrl != null
                      ? NetworkImage(reply.authorAvatarUrl!)
                      : null,
                  child: reply.authorAvatarUrl == null
                      ? const Icon(Icons.person, size: 12)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reply.authorName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$dateStr$editedStr',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                _buildThreeDotsMenu(reply, currentUserId),
              ],
            ),
            const SizedBox(height: 8),
            _buildTextWithLinks(reply.content, context, fontSize: 13),
            _buildAttachmentsList(reply.attachments),
            const SizedBox(height: 8),
            _buildCommentActionsRow(reply),
          ],
        ),
      ),
    );

    return cardContent;
  }

  Widget _buildThreeDotsMenu(DiscussionReply reply, String? currentUserId) {
    final isOwn = reply.authorId == currentUserId;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (val) {
        if (val == 'reply') {
          _startReplyMode(reply);
        } else if (val == 'edit') {
          _startEditMode(reply);
        } else if (val == 'delete') {
          _confirmDeleteReply(reply);
        }
      },
      itemBuilder: (context) {
        if (isOwn) {
          return [
            const PopupMenuItem(
              value: 'reply',
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Reply'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ];
        } else {
          return [
            const PopupMenuItem(
              value: 'reply',
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Reply'),
                ],
              ),
            ),
          ];
        }
      },
    );
  }

  Widget _buildCommentActionsRow(DiscussionReply reply) {
    final upvoted = reply.userVoteType == 1;
    final downvoted = reply.userVoteType == -1;

    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_upward_rounded,
            color: upvoted ? Colors.deepPurple : Colors.grey.shade500,
            size: 18,
          ),
          onPressed: () => _voteReply(reply.id, 1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        Text(
          reply.score.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: upvoted
                ? Colors.deepPurple
                : (downvoted ? Colors.red : Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.arrow_downward_rounded,
            color: downvoted ? Colors.red : Colors.grey.shade500,
            size: 18,
          ),
          onPressed: () => _voteReply(reply.id, -1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () => _startReplyMode(reply),
          child: Text(
            'Reply',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  void _startReplyMode(DiscussionReply reply) {
    setState(() {
      _editingReply = null;
      _replyingTo = reply;
      _replyController.text = '';
    });
  }

  void _startEditMode(DiscussionReply reply) {
    setState(() {
      _replyingTo = null;
      _editingReply = reply;
      _replyController.text = reply.content;
      _commentAttachments.clear();
      for (var att in reply.attachments) {
        _commentAttachments.add(PendingAttachment(
          name: att.name,
          type: att.type,
          linkUrl: att.type == 'link' ? att.url : null,
          remoteUrl: att.type != 'link' ? att.url : null,
        ));
      }
    });
  }

  void _confirmDeleteReply(DiscussionReply reply) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone and will delete any replies to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final repo = this.context.read<DiscussionRepository>();
                await repo.deleteReply(reply.id);
                await _loadDetails();
              } catch (e) {
                setState(() => _isLoading = false);
                _showSnackBar('Failed to delete comment: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context, int depth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      if (depth == 0) return Colors.grey.shade900;
      if (depth == 1) return const Color(0xFF262626);
      if (depth == 2) return Colors.grey.shade800;
      return const Color(0xFF383838);
    } else {
      if (depth == 0) return Colors.white;
      if (depth == 1) return const Color(0xFFF8F4FF);
      if (depth == 2) return const Color(0xFFF1EAFF);
      return const Color(0xFFE8D9FF);
    }
  }

  Color _getBorderColor(BuildContext context, int depth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.grey.shade800;
    } else {
      if (depth == 0) return Colors.grey.shade200;
      if (depth == 1) return const Color(0xFFE8DFFF);
      if (depth == 2) return const Color(0xFFDCD0FF);
      return const Color(0xFFD0C0FF);
    }
  }
}

class CommentNode {
  final DiscussionReply reply;
  final List<CommentNode> children = [];

  CommentNode(this.reply);
}
