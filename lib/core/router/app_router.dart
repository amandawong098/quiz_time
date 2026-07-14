import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/library/screens/my_quizzes_screen.dart';
import '../../features/learn/screens/learn_screen.dart';
import '../../features/learn/screens/lesson_player_screen.dart';
import '../../features/learn/screens/my_lessons_screen.dart';
import '../../features/learn/screens/sub_chapter_slides_screen.dart';
import '../../features/learn/screens/slide_block_editor_screen.dart';
import '../../features/learn/screens/create_lesson_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
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
import '../../features/profile/screens/friends_screen.dart';
import '../../features/learn/screens/my_flashcards_screen.dart';
import '../../features/learn/screens/create_flashcard_deck_screen.dart';
import '../../features/learn/screens/manage_cards_screen.dart';
import '../../features/learn/screens/play_flashcards_screen.dart';
import '../../features/learn/screens/flashcard_details_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
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
        GoRoute(
          path: '/',
          builder: (context, state) {
            final courseId = state.uri.queryParameters['selectedCourseId'];
            return LearnScreen(selectedCourseId: courseId);
          },
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const DiscoverScreen(),
        ),
        GoRoute(
          path: '/my-quizzes',
          builder: (context, state) => const MyQuizzesScreen(),
        ),
        GoRoute(
          path: '/my-discussions',
          builder: (context, state) => const MyDiscussionsScreen(),
        ),
        GoRoute(
          path: '/my-lessons',
          builder: (context, state) => const MyLessonsScreen(),
        ),

        GoRoute(
          path: '/discussions',
          builder: (context, state) => const DiscussionsDummyScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/me',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const EditProfileScreen(),
            ),
            GoRoute(
              path: 'friends',
              builder: (context, state) => const FriendsScreen(),
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
      builder: (context, state) {
        final challengeId = state.uri.queryParameters['challengeId'];
        final shuffle = state.uri.queryParameters['shuffle'] == 'true';
        final isPreview = state.uri.queryParameters['preview'] == 'true' || state.uri.queryParameters['isPreview'] == 'true';
        final initialQuestionId = state.uri.queryParameters['initialQuestionId'];
        return TakeQuizScreen(
          quizId: state.pathParameters['id']!,
          challengeId: challengeId,
          shuffle: shuffle,
          isPreview: isPreview,
          initialQuestionId: initialQuestionId,
        );
      },
    ),
    GoRoute(
      path: '/quiz/:id/review',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        final challengeId = state.uri.queryParameters['challengeId'];
        return QuizReviewScreen(
          quizId: state.pathParameters['id']!,
          attemptId: extra?['attemptId'] ?? '',
          challengeId: challengeId,
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
      path: '/create-lesson',
      builder: (context, state) {
        final Map<String, dynamic>? extra =
            state.extra as Map<String, dynamic>?;
        return CreateLessonScreen(lesson: extra?['lesson']);
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
        return CreateTopicScreen(
          topic: extra?['topic'],
          courseId: extra?['courseId'],
          chapterId: extra?['chapterId'],
          subChapterId: extra?['subChapterId'],
          pageId: extra?['pageId'],
          quizId: extra?['quizId'],
          questionId: extra?['questionId'],
          deckId: extra?['deckId'],
          cardId: extra?['cardId'],
        );
      },
    ),
    GoRoute(
      path: '/discussion/:id',
      builder: (context, state) =>
          DiscussionDetailsScreen(topicId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/lesson-player',
      builder: (context, state) {
        final subChapterId = state.uri.queryParameters['subChapterId'];
        final courseId = state.uri.queryParameters['courseId'];
        final isPreview = state.uri.queryParameters['preview'] == 'true' || state.uri.queryParameters['isPreview'] == 'true';
        final initialPageId = state.uri.queryParameters['initialPageId'];
        return LessonPlayerScreen(
          subChapterId: subChapterId,
          courseId: courseId,
          isPreview: isPreview,
          initialPageId: initialPageId,
        );
      },
    ),
    GoRoute(
      path: '/my-lessons/sub-chapter/:id/slides',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        return SubChapterSlidesScreen(
          subChapterId: state.pathParameters['id']!,
          subChapterTitle: extra?['subChapterTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/my-lessons/page/:id/editor',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        return SlideBlockEditorScreen(
          pageId: state.pathParameters['id']!,
          pageTitle: extra?['pageTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/my-flashcards',
      builder: (context, state) => const MyFlashcardsScreen(),
    ),
    GoRoute(
      path: '/create-flashcard-deck',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        return CreateFlashcardDeckScreen(deck: extra?['deck']);
      },
    ),
    GoRoute(
      path: '/my-flashcards/deck/:id/cards',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        return ManageCardsScreen(
          deckId: state.pathParameters['id']!,
          deckTitle: extra?['deckTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/flashcard-deck/:id/play',
      builder: (context, state) {
        final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
        final shuffle = state.uri.queryParameters['shuffle'] == 'true';
        return PlayFlashcardsScreen(
          deckId: state.pathParameters['id']!,
          deckTitle: extra?['deckTitle'] as String? ?? '',
          shuffle: shuffle,
        );
      },
    ),
    GoRoute(
      path: '/flashcard-deck/:id/details',
      builder: (context, state) {
        return FlashcardDetailsScreen(
          deckId: state.pathParameters['id']!,
        );
      },
    ),
  ],
);
