import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/library/screens/my_quizzes_screen.dart';
import '../../features/lessons/screens/lessons_dummy_screen.dart';
import '../../features/leaderboard/screens/leaderboard_dummy_screen.dart';
import '../../features/discussions/screens/discussions_dummy_screen.dart';
import '../../features/discussions/screens/create_topic_screen.dart';
import '../../features/discussions/screens/discussion_details_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/quiz/screens/quiz_details_screen.dart';
import '../../features/quiz/screens/take_quiz_screen.dart';
import '../../features/quiz/screens/quiz_review_screen.dart';
import '../../features/library/screens/create_quiz_screen.dart';
import '../../features/library/screens/create_question_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/my_discussions_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/lessons',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isGoingToLogin = state.uri.toString() == '/login';

    if (session == null && !isGoingToLogin) {
      return '/login';
    }
    if (session != null && isGoingToLogin) {
      return '/lessons';
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
          path: '/my-discussions',
          builder: (context, state) => const MyDiscussionsScreen(),
        ),
        GoRoute(
          path: '/lessons',
          builder: (context, state) => const LessonsDummyScreen(),
        ),
        GoRoute(
          path: '/discussions',
          builder: (context, state) => const DiscussionsDummyScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardDummyScreen(),
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
    GoRoute(
      path: '/create-topic',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        return CreateTopicScreen(topic: extra?['topic']);
      },
    ),
    GoRoute(
      path: '/discussion/:id',
      builder: (context, state) =>
          DiscussionDetailsScreen(topicId: state.pathParameters['id']!),
    ),
  ],
);
