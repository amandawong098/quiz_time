import 'package:flutter/material.dart';
import '../../../core/widgets/notification_badge.dart';

class LeaderboardDummyScreen extends StatelessWidget {
  const LeaderboardDummyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> mockLeaders = [
      {
        'name': 'Sarah Chen',
        'points': '2,450 XP',
        'rank': 4,
        'change': 'up',
      },
      {
        'name': 'Alex Rivera',
        'points': '2,310 XP',
        'rank': 5,
        'change': 'down',
      },
      {
        'name': 'Sophia Wu',
        'points': '2,180 XP',
        'rank': 6,
        'change': 'up',
      },
      {
        'name': 'Ryan Park',
        'points': '2,050 XP',
        'rank': 7,
        'change': 'same',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        elevation: 0,
        actions: const [NotificationIconBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Podium UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd Place
                _buildPodiumItem(
                  context: context,
                  name: 'David Kim',
                  points: '2,890 XP',
                  rank: 2,
                  height: 120,
                  avatarColor: Colors.blue.shade100,
                  iconColor: Colors.blue.shade800,
                  badgeColor: Colors.grey.shade400,
                ),
                // 1st Place
                _buildPodiumItem(
                  context: context,
                  name: 'Emma Watson',
                  points: '3,210 XP',
                  rank: 1,
                  height: 150,
                  avatarColor: Colors.amber.shade100,
                  iconColor: Colors.amber.shade900,
                  badgeColor: Colors.amber.shade600,
                  isWinner: true,
                ),
                // 3rd Place
                _buildPodiumItem(
                  context: context,
                  name: 'Liam Vance',
                  points: '2,670 XP',
                  rank: 3,
                  height: 100,
                  avatarColor: Colors.orange.shade100,
                  iconColor: Colors.orange.shade900,
                  badgeColor: Colors.orange.shade600,
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Ranks list
            const Text(
              'Global Rankings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...mockLeaders.map((leader) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        alignment: Alignment.center,
                        child: Text(
                          '#${leader['rank']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.deepPurple.shade50,
                        child: Text(
                          leader['name'][0],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leader['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        leader['points'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildChangeIcon(leader['change']),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            // Coming Soon Notice
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 40,
                    color: Colors.deepPurple.shade800,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Leaderboards Coming Soon!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Global competition ranks are currently under construction. Keep playing quizzes to bank XP for the upcoming launch!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple.shade700,
                      height: 1.4,
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

  Widget _buildPodiumItem(
      {required BuildContext context,
      required String name,
      required String points,
      required int rank,
      required double height,
      required Color avatarColor,
      required Color iconColor,
      required Color badgeColor,
      bool isWinner = false}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: isWinner ? 36 : 28,
              backgroundColor: avatarColor,
              child: Icon(
                Icons.person,
                color: iconColor,
                size: isWinner ? 36 : 28,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isWinner ? 13 : 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isWinner
                  ? [Colors.deepPurple, Colors.deepPurple.shade700]
                  : [Colors.deepPurple.shade200, Colors.deepPurple.shade300],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                points.split(' ')[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChangeIcon(String change) {
    if (change == 'up') {
      return const Icon(Icons.arrow_upward, color: Colors.green, size: 16);
    } else if (change == 'down') {
      return const Icon(Icons.arrow_downward, color: Colors.red, size: 16);
    } else {
      return const Icon(Icons.remove, color: Colors.grey, size: 16);
    }
  }
}
