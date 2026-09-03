import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/discussion_models.dart';
import '../../../data/repositories/discussion_repository.dart';

class DiscussionModerationScreen extends StatefulWidget {
  const DiscussionModerationScreen({super.key});

  @override
  State<DiscussionModerationScreen> createState() => _DiscussionModerationScreenState();
}

class _DiscussionModerationScreenState extends State<DiscussionModerationScreen> {
  bool _isLoading = true;
  List<DiscussionReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<DiscussionRepository>();
      final reports = await repo.getPendingReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading moderation reports: $e')),
        );
      }
    }
  }

  Future<void> _dismissReport(DiscussionReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss Report?'),
        content: const Text(
          'This will mark the report as dismissed. The reported content will remain visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Dismiss Report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = context.read<DiscussionRepository>();
      await repo.dismissReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report dismissed.')),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dismiss report: $e')),
        );
      }
    }
  }

  Future<void> _deleteContent(DiscussionReport report) async {
    final isReply = report.isReply;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${isReply ? "Reply" : "Topic"}?'),
        content: Text(
          'Are you sure you want to delete this ${isReply ? "reply" : "topic and all its replies"}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = context.read<DiscussionRepository>();
      await repo.deleteReportedContent(
        reportId: report.id,
        topicId: report.topicId,
        replyId: report.replyId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isReply ? "Reply" : "Topic"} deleted successfully.'),
            backgroundColor: Colors.deepPurple,
          ),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete content: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Moderation Hub',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadReports,
            tooltip: 'Refresh Reports',
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _reports.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Colors.deepPurple,
                  onRefresh: _loadReports,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return _buildReportCard(report);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'All Clear!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending discussion reports to review. The community discussions are healthy and safe!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: BorderSide(color: Colors.deepPurple.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReportDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, ${dt.year} • $h:$min $ampm';
  }

  Widget _buildReportCard(DiscussionReport report) {
    final isReply = report.isReply;
    final dateStr = _formatReportDate(report.createdAt);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Type badge, report date, pending pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReply ? Colors.blue.shade50 : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isReply ? Colors.blue.shade300 : Colors.purple.shade300,
                    ),
                  ),
                  child: Text(
                    isReply ? 'REPORTED REPLY' : 'REPORTED TOPIC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isReply ? Colors.blue.shade800 : Colors.purple.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Report Reason Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reason: ${report.reason}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (report.details != null && report.details!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Details: "${report.details}"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Reported on: $dateStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Content preview container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isReply) ...[
                    Text(
                      report.topicTitle ?? 'Untitled Topic',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (report.topicContent != null && report.topicContent!.trim().isNotEmpty)
                          ? report.topicContent!
                          : '(No topic description provided)',
                      style: TextStyle(
                        fontSize: 13,
                        color: (report.topicContent != null && report.topicContent!.trim().isNotEmpty)
                            ? Colors.grey.shade800
                            : Colors.grey.shade500,
                        fontStyle: (report.topicContent != null && report.topicContent!.trim().isNotEmpty)
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    if (report.topicTitle != null && report.topicTitle!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'In Topic: "${report.topicTitle}"',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    Text(
                      (report.replyContent != null && report.replyContent!.trim().isNotEmpty)
                          ? report.replyContent!
                          : '(Empty reply content)',
                      style: TextStyle(
                        fontSize: 13,
                        color: (report.replyContent != null && report.replyContent!.trim().isNotEmpty)
                            ? Colors.black87
                            : Colors.grey.shade500,
                        fontStyle: (report.replyContent != null && report.replyContent!.trim().isNotEmpty)
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Moderation Actions Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/discussion/${report.topicId}');
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View in Discussion'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: BorderSide(color: Colors.deepPurple.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _dismissReport(report),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Dismiss'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteContent(report),
                        icon: const Icon(Icons.delete_forever_rounded, size: 16),
                        label: const Text('Delete Content'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
