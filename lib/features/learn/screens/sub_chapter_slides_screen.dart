import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../models/lesson_models.dart';

class SubChapterSlidesScreen extends StatefulWidget {
  final String subChapterId;
  final String subChapterTitle;
  const SubChapterSlidesScreen({
    super.key,
    required this.subChapterId,
    required this.subChapterTitle,
  });

  @override
  State<SubChapterSlidesScreen> createState() => _SubChapterSlidesScreenState();
}

class _SubChapterSlidesScreenState extends State<SubChapterSlidesScreen> {
  bool _isLoading = true;
  List<LessonPage> _pages = [];
  Map<String, int> _blockCountMap = {};

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      final pages = await repo.getPages(widget.subChapterId);
      final Map<String, int> countMap = {};

      for (var page in pages) {
        if (!mounted) return;
        final blocks = await repo.getBlocks(page.id);
        countMap[page.id] = blocks.length;
      }

      if (!mounted) return;
      setState(() {
        _pages = pages;
        _blockCountMap = countMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading slides: ${e.toString()}')),
      );
    }
  }

  Future<void> _addPage() async {
    try {
      final repo = context.read<LessonRepository>();
      await repo.createPage(
        subChapterId: widget.subChapterId,
        position: _pages.length,
      );
      if (mounted) _loadPages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating slide page: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deletePage(LessonPage page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slide Page?'),
        content: const Text(
          'Are you sure you want to delete this slide page? This action will remove all elements inside it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.deletePage(page.id);
        if (mounted) _loadPages();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting page: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _reorderPage(LessonPage page, bool moveUp) async {
    final int index = _pages.indexOf(page);
    if (moveUp && index == 0) return;
    if (!moveUp && index == _pages.length - 1) return;

    final targetIndex = moveUp ? index - 1 : index + 1;
    final targetPage = _pages[targetIndex];

    try {
      final repo = context.read<LessonRepository>();
      await repo.updatePage(page.id, targetPage.position);
      await repo.updatePage(targetPage.id, page.position);
      if (mounted) _loadPages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering pages: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subChapterTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.collections_bookmark_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pages in this sub-chapter',
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
                          'Add a page/slide to begin building the lesson flow.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addPage,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Slide Page'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPages,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final blockCount = _blockCountMap[page.id] ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.shade50,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                           title: Text(
                            'Slide ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text('$blockCount elements (blocks)'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward, size: 20),
                                onPressed: index == 0
                                    ? null
                                    : () => _reorderPage(page, true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward, size: 20),
                                onPressed: index == _pages.length - 1
                                    ? null
                                    : () => _reorderPage(page, false),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'delete') {
                                    _deletePage(page);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Delete Page',
                                            style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () async {
                            final changed = await context.push(
                              '/my-lessons/page/${page.id}/editor',
                              extra: {'pageTitle': 'Slide ${index + 1}'},
                            );
                            if (changed == true) {
                              _loadPages();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _pages.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              onPressed: _addPage,
              icon: const Icon(Icons.add),
              label: const Text('Add Slide Page'),
            ),
    );
  }
}
