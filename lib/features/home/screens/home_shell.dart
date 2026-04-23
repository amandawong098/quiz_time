import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_time/l10n/app_localizations.dart';

class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/my-quizzes')) {
      return 1;
    }
    if (location.startsWith('/history')) {
      return 2;
    }
    if (location.startsWith('/me')) {
      return 3;
    }
    return 0; // default to discover
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/my-quizzes');
        break;
      case 2:
        context.go('/history');
        break;
      case 3:
        context.go('/me');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) => _onItemTapped(index, context),
          type: BottomNavigationBarType.fixed,
          elevation: 0, // Disable default elevation since we have custom shadow
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.search),
              label: l10n.discover,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.book),
              label: l10n.myQuizzes,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history),
              label: l10n.history,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: l10n.me,
            ),
          ],
        ),
      ),
    );
  }
}
