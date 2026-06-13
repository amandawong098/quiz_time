import 'package:flutter/material.dart';
import '../../../core/widgets/notification_badge.dart';
import '../widgets/lessons_tab.dart';
import '../widgets/flashcards_tab.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        children: const [
          LessonsTab(),
          FlashcardsTab(),
        ],
      ),
    );
  }
}
