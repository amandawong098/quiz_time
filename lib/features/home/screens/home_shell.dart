import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/' ||
        location.startsWith('/lesson-player') ||
        location.startsWith('/create-lesson')) {
      return 0;
    }
    if (location.startsWith('/discover') ||
        location.startsWith('/quiz') ||
        location.startsWith('/create-quiz') ||
        location.startsWith('/create-questions')) {
      return 1;
    }
    if (location.startsWith('/leaderboard')) {
      return 2;
    }
    if (location.startsWith('/discussions') ||
        location.startsWith('/create-topic') ||
        location.startsWith('/discussion/')) {
      return 3;
    }
    if (location.startsWith('/me') ||
        location.startsWith('/my-discussions') ||
        location.startsWith('/my-lessons') ||
        location.startsWith('/my-quizzes')) {
      return 4;
    }
    return 0; // default to Learn
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/discover');
        break;
      case 2:
        context.go('/leaderboard');
        break;
      case 3:
        context.go('/discussions');
        break;
      case 4:
        context.go('/me');
        break;
    }
  }

  void _showComingSoonSnackBar(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 10),
            Text('$featureName feature is coming soon!'),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, int selectedIndex) {
    final String location = GoRouterState.of(context).uri.path;

    // Hide FAB on Leaderboard, all Profile screens/sub-routes, and Learn screen
    if (location.startsWith('/leaderboard') ||
        location.startsWith('/me') ||
        location.startsWith('/my-lessons') ||
        location == '/' ||
        location.startsWith('/lesson-player') ||
        location.startsWith('/create-lesson')) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () {
        if (location.startsWith('/learn')) {
          _showComingSoonSnackBar(context, 'Create Learning Content');
        } else if (location.startsWith('/discussions') ||
            location.startsWith('/my-discussions')) {
          context.push('/create-topic');
        } else {
          // Default to create quiz (for / or /my-quizzes)
          context.push('/create-quiz');
        }
      },
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: _buildFloatingActionButton(context, selectedIndex),
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
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(index, context),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: 'Learn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_turned_in_rounded),
              label: 'Quizzes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_rounded),
              label: 'Discussions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
