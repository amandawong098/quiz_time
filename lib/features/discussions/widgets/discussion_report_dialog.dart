import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/discussion_repository.dart';

class DiscussionReportDialog extends StatefulWidget {
  final String topicId;
  final String? replyId;

  const DiscussionReportDialog({
    super.key,
    required this.topicId,
    this.replyId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String topicId,
    String? replyId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DiscussionReportDialog(
        topicId: topicId,
        replyId: replyId,
      ),
    );
  }

  @override
  State<DiscussionReportDialog> createState() => _DiscussionReportDialogState();
}

class _DiscussionReportDialogState extends State<DiscussionReportDialog> {
  static const List<String> _reasons = [
    'Inappropriate or Offensive Language',
    'Harassment or Hate Speech',
    'Spam or Irrelevant Advertising',
    'Misinformation or Misleading Answers',
    'Other Violations',
  ];

  String _selectedReason = _reasons.first;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = context.read<DiscussionRepository>();
      if (widget.replyId != null) {
        await repo.reportReply(
          topicId: widget.topicId,
          replyId: widget.replyId!,
          reason: _selectedReason,
          details: _detailsController.text.trim().isNotEmpty
              ? _detailsController.text.trim()
              : null,
        );
      } else {
        await repo.reportTopic(
          topicId: widget.topicId,
          reason: _selectedReason,
          details: _detailsController.text.trim().isNotEmpty
              ? _detailsController.text.trim()
              : null,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted. Our moderation team has been notified and will review this content.',
            ),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.replyId != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.report_problem_rounded, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Text(isReply ? 'Report Reply' : 'Report Topic'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this ${isReply ? "reply" : "discussion topic"}?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._reasons.map((reason) {
              return RadioListTile<String>(
                value: reason,
                groupValue: _selectedReason,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.deepPurple,
                title: Text(reason, style: const TextStyle(fontSize: 13)),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedReason = val);
                  }
                },
              );
            }),
            const SizedBox(height: 12),
            const Text(
              'Additional Details (optional):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
