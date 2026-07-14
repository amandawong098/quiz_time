import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/notification_badge.dart';
import '../widgets/lessons_tab.dart';
import '../widgets/flashcards_tab.dart';

class LearnScreen extends StatefulWidget {
  final String? selectedCourseId;
  final String? initialTab;
  const LearnScreen({super.key, this.selectedCourseId, this.initialTab});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final GlobalKey<LessonsTabState> _lessonsTabKey = GlobalKey<LessonsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialTab == 'flashcards') {
      _tabController.index = 1;
    }
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant LearnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCourseId != null && widget.selectedCourseId != oldWidget.selectedCourseId) {
      _tabController.animateTo(0);
    } else if (widget.initialTab == 'flashcards' && widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        elevation: 0,
        actions: const [NotificationIconBadge()],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(
              icon: Icon(Icons.menu_book_rounded),
              text: 'Lessons',
            ),
            Tab(
              icon: Icon(Icons.style_rounded),
              text: 'Flashcards',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LessonsTab(
            key: _lessonsTabKey,
            initialCourseId: widget.selectedCourseId,
            onBrowseModeChanged: () {
              if (mounted) setState(() {});
            },
          ),
          const FlashcardsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0 &&
              (_lessonsTabKey.currentState?.isShowingBrowseMode ?? false)
          ? FloatingActionButton(
              onPressed: () async {
                final result = await context.push<bool>('/create-lesson');
                if (result == true) {
                  _lessonsTabKey.currentState?.loadDbLessons();
                }
              },
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
