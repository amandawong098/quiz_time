import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/models/quiz_models.dart';

class PlayerLiveState {
  final String userId;
  final String name;
  final String? avatarUrl;
  bool isAnswered;
  List<String> selectedOptionIds;
  bool isCorrect;
  int currentRoundScore;
  int totalScore;
  int streak;
  bool isQuit;
  bool isHost;

  PlayerLiveState({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isAnswered = false,
    this.selectedOptionIds = const [],
    this.isCorrect = false,
    this.currentRoundScore = 0,
    this.totalScore = 0,
    this.streak = 0,
    this.isQuit = false,
    this.isHost = false,
  });
}

/// Floating Emoji Particle Model
class FloatingEmoji {
  final String id;
  final String emoji;
  final double xRatio; // 0.1 to 0.9 across screen
  final double scale;
  final DateTime createdAt;

  FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.xRatio,
    required this.scale,
    required this.createdAt,
  });
}

/// Floating Emoji Overlay Widget
class FloatingEmojiOverlay extends StatefulWidget {
  final List<FloatingEmoji> emojis;

  const FloatingEmojiOverlay({super.key, required this.emojis});

  @override
  State<FloatingEmojiOverlay> createState() => _FloatingEmojiOverlayState();
}

class _FloatingEmojiOverlayState extends State<FloatingEmojiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.emojis.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: widget.emojis.map((item) {
              final elapsedMs = now.difference(item.createdAt).inMilliseconds;
              final progress = (elapsedMs / 2000.0).clamp(0.0, 1.0);
              if (progress >= 1.0) return const SizedBox.shrink();

              final dy = size.height * (1.0 - progress * 0.7);
              final dx = size.width * item.xRatio + sin(progress * 6.0) * 20.0;
              final opacity = (1.0 - progress).clamp(0.0, 1.0);

              return Positioned(
                left: dx,
                top: dy,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: item.scale * (0.8 + progress * 0.4),
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Waiting banner shown on Question screen when the current player has locked in their answer.
class KahootWaitingBanner extends StatelessWidget {
  final int answeredCount;
  final int totalCount;
  final Function(String emoji) onSendEmoji;

  const KahootWaitingBanner({
    super.key,
    required this.answeredCount,
    required this.totalCount,
    required this.onSendEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? (answeredCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.black, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Answer Locked In!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Waiting for others ($answeredCount / $totalCount answered)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          // Reaction emojis tray
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['🔥', '👏', '😱', '😂', '🎯', '💀'].map((emoji) {
              return InkWell(
                onTap: () => onSendEmoji(emoji),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Kahoot Reveal View: displays Correct/Incorrect banner, speed points, streak, and answer distribution chart
class KahootRevealView extends StatelessWidget {
  final bool isCorrect;
  final bool isTimedOut;
  final int pointsEarned;
  final int streak;
  final Question question;
  final List<String> userSelectedOptionIds;
  final Map<String, int> optionVoteCounts;
  final int totalAnswered;
  final VoidCallback onContinue;
  final Function(String emoji) onSendEmoji;

  const KahootRevealView({
    super.key,
    required this.isCorrect,
    required this.isTimedOut,
    required this.pointsEarned,
    required this.streak,
    required this.question,
    required this.userSelectedOptionIds,
    required this.optionVoteCounts,
    required this.totalAnswered,
    required this.onContinue,
    required this.onSendEmoji,
  });

  @override
  Widget build(BuildContext context) {
    Color bannerBg;
    IconData bannerIcon;
    String bannerTitle;

    if (isTimedOut) {
      bannerBg = Colors.orange.shade700;
      bannerIcon = Icons.timer_off_rounded;
      bannerTitle = "TIME'S UP!";
    } else if (isCorrect) {
      bannerBg = Colors.green.shade600;
      bannerIcon = Icons.check_circle_rounded;
      bannerTitle = "CORRECT!";
    } else {
      bannerBg = Colors.red.shade600;
      bannerIcon = Icons.cancel_rounded;
      bannerTitle = "INCORRECT";
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Top Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: bannerBg,
                boxShadow: [
                  BoxShadow(
                    color: bannerBg.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(bannerIcon, color: Colors.white, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    bannerTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$pointsEarned pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (streak > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🔥 Streak $streak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Middle: Answer Distribution Chart
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Answer Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: question.options.length,
                        itemBuilder: (context, index) {
                          final option = question.options[index];
                          final count = optionVoteCounts[option.id] ?? 0;
                          final pct = totalAnswered > 0 ? (count / totalAnswered) : 0.0;
                          final isUserSelected = userSelectedOptionIds.contains(option.id);
                          final isOptionCorrect = option.isCorrect;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOptionCorrect
                                  ? Colors.green.shade50
                                  : (isUserSelected ? Colors.red.shade50 : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOptionCorrect
                                    ? Colors.green.shade500
                                    : (isUserSelected ? Colors.red.shade400 : Colors.grey.shade300),
                                width: isOptionCorrect || isUserSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isOptionCorrect)
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                    else if (isUserSelected)
                                      const Icon(Icons.cancel, color: Colors.red, size: 20)
                                    else
                                      Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        option.optionText,
                                        style: TextStyle(
                                          fontWeight: isOptionCorrect ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isUserSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'You',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '$count',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isOptionCorrect ? Colors.green.shade700 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOptionCorrect ? Colors.green : Colors.deepPurple.shade300,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Reaction Bar & Auto Countdown notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['🔥', '👏', '😱', '😂', '🎯', '💀'].map((emoji) {
                        return InkWell(
                          onTap: () => onSendEmoji(emoji),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Scoreboard'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kahoot Intermediate Scoreboard View
class KahootScoreboardView extends StatelessWidget {
  final List<PlayerLiveState> players;
  final int currentQuestionIndex;
  final int totalQuestions;
  final bool isHost;
  final bool useTimer;
  final int secondsRemaining;
  final VoidCallback onNextQuestion;
  final String currentUserId;
  final Function(String emoji) onSendEmoji;

  const KahootScoreboardView({
    super.key,
    required this.players,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.isHost,
    required this.useTimer,
    required this.secondsRemaining,
    required this.onNextQuestion,
    required this.currentUserId,
    required this.onSendEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final isLastQuestion = currentQuestionIndex >= totalQuestions - 1;

    // Sort players by totalScore descending
    final sortedPlayers = List<PlayerLiveState>.from(players)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade900,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                children: [
                  const Text(
                    'LEADERBOARD',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Question ${currentQuestionIndex + 1} of $totalQuestions',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Ranking List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: sortedPlayers.length,
                itemBuilder: (context, index) {
                  final p = sortedPlayers[index];
                  final isMe = p.userId == currentUserId;

                  Widget rankBadge;
                  if (index == 0) {
                    rankBadge = const Text('🥇', style: TextStyle(fontSize: 24));
                  } else if (index == 1) {
                    rankBadge = const Text('🥈', style: TextStyle(fontSize: 24));
                  } else if (index == 2) {
                    rankBadge = const Text('🥉', style: TextStyle(fontSize: 24));
                  } else {
                    rankBadge = Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.deepPurple.shade700
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMe ? Colors.amber : Colors.white.withValues(alpha: 0.15),
                        width: isMe ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        rankBadge,
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                              ? NetworkImage(p.avatarUrl!)
                              : null,
                          child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                              ? Text(
                                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (p.isQuit) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'LEFT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (p.streak >= 2) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '🔥 ${p.streak} in a row',
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${p.totalScore} pts',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (p.currentRoundScore > 0)
                              Text(
                                '+${p.currentRoundScore}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls Area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E0A3C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Reaction Tray
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['🔥', '👏', '😱', '😂', '🎯', '💀'].map((emoji) {
                      return InkWell(
                        onTap: () => onSendEmoji(emoji),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  if (useTimer) ...[
                    // Timed mode: countdown indicator
                    Text(
                      isLastQuestion
                          ? 'Finishing quiz in $secondsRemaining seconds...'
                          : 'Next question in $secondsRemaining seconds...',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (secondsRemaining / 5.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                        minHeight: 6,
                      ),
                    ),
                  ] else ...[
                    // Untimed mode: Host controls next question
                    if (isHost)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onNextQuestion,
                          child: Text(
                            isLastQuestion ? 'View Final Results 🏆' : 'Next Question ➔',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isLastQuestion
                                  ? 'Waiting for host to end quiz...'
                                  : 'Waiting for host to start next question...',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
