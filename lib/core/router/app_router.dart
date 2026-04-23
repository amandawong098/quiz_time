import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/library/screens/my_quizzes_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/quiz/screens/quiz_details_screen.dart';
import '../../features/quiz/screens/take_quiz_screen.dart';
import '../../features/quiz/screens/quiz_review_screen.dart';
import '../../features/library/screens/create_quiz_screen.dart';
import '../../features/library/screens/create_question_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isGoingToLogin = state.uri.toString() == '/login';

    if (session == null && !isGoingToLogin) {
      return '/login';
    }
    if (session != null && isGoingToLogin) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DiscoverScreen()),
        GoRoute(
          path: '/my-quizzes',
          builder: (context, state) => const MyQuizzesScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/me',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const EditProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/quiz/:id',
      builder: (context, state) =>
          QuizDetailsScreen(quizId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/quiz/:id/take',
      builder: (context, state) =>
          TakeQuizScreen(quizId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/quiz/:id/review',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
        return QuizReviewScreen(
          quizId: state.pathParameters['id']!,
          attemptId: extra['attemptId'],
        );
      },
    ),
    GoRoute(
      path: '/create-quiz',
      builder: (context, state) {
        final Map<String, dynamic>? extra =
            state.extra as Map<String, dynamic>?;
        return CreateQuizScreen(quiz: extra?['quiz']);
      },
    ),
    GoRoute(
      path: '/create-questions',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        return CreateQuestionScreen(
          initialQuizData: extra!['quiz'],
          initialQuestionsData: extra['generatedQuestions'],
        );
      },
    ),
  ],
);
