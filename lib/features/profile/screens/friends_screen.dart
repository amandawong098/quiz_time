import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/friendship_repository.dart';
import '../../../data/models/friendship_models.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _friendsSearchController = TextEditingController();
  final TextEditingController _discoverSearchController = TextEditingController();
  String _friendsQuery = '';
  String _discoverQuery = '';
  bool _isLoading = true;
  bool _isActionInProgress = false;

  List<UserProfile> _friends = [];
  List<UserProfile> _incomingRequests = [];
  List<UserProfile> _sentRequests = [];
  List<UserProfile> _discoverNewFriends = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendsSearchController.dispose();
    _discoverSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showFullLoading = true}) async {
    if (showFullLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final repo = context.read<FriendshipRepository>();
      final friends = await repo.getFriends();
      final incoming = await repo.getIncomingRequests();
      final sent = await repo.getSentRequests();
      final discover = await repo.getDiscoverNewFriends();

      if (mounted) {
        setState(() {
          _friends = friends;
          _incomingRequests = incoming;
          _sentRequests = sent;
          _discoverNewFriends = discover;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading network data: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _performAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _isActionInProgress = true);
    try {
      await action();
      _showSnackBar(successMessage);
      await _loadData();
    } catch (e) {
      _showSnackBar('Action failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Widget _buildRequestList({
    required List<UserProfile> list,
    required String title,
    required Widget Function(UserProfile user) actionBuilder,
    required String emptyText,
  }) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final user = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  backgroundColor: Colors.deepPurple.shade100,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.deepPurple)
                      : null,
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: actionBuilder(user),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final filtered = _friends
        .where((f) => f.name.toLowerCase().contains(_friendsQuery.toLowerCase()))
        .toList();

    return RefreshIndicator(
      onRefresh: () => _loadData(showFullLoading: false),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(
              controller: _friendsSearchController,
              hintText: 'Search friends by name...',
              onChanged: (val) {
                setState(() {
                  _friendsQuery = val;
                });
              },
            ),
            Expanded(
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 64.0,
                            horizontal: 16.0,
                          ),
                          child: Center(
                            child: Text(
                              _friendsQuery.isEmpty
                                  ? 'You haven\'t added any friends yet.\nGo to "Discover" tab to add new connections!'
                                  : 'No friends matching "$_friendsQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                final friend = _friends[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
                          ? NetworkImage(friend.avatarUrl!)
                          : null,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: (friend.avatarUrl == null || friend.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.deepPurple)
                          : null,
                    ),
                    title: Text(
                      friend.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      friend.email,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.person_remove_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Unfriend ${friend.name}?'),
                            content: const Text(
                              'Are you sure you want to remove this friend? Unfriending won\'t alert them.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Unfriend',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && mounted) {
                          _performAction(
                            () => context.read<FriendshipRepository>().unfriend(
                              friend.id,
                            ),
                            'Unfriended ${friend.name}.',
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDiscoverTab() {
    final filtered = _discoverNewFriends
        .where((u) => u.name.toLowerCase().contains(_discoverQuery.toLowerCase()))
        .toList();

    return RefreshIndicator(
      onRefresh: () => _loadData(showFullLoading: false),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(
              controller: _discoverSearchController,
              hintText: 'Search people to discover...',
              onChanged: (val) {
                setState(() {
                  _discoverQuery = val;
                });
              },
            ),
            Expanded(
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 64.0,
                            horizontal: 16.0,
                          ),
                          child: Center(
                            child: Text(
                              _discoverQuery.isEmpty
                                  ? 'No new profiles found to discover.'
                                  : 'No profiles matching "$_discoverQuery"',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                final user = _discoverNewFriends[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.deepPurple)
                          : null,
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      user.email,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        _performAction(
                          () => context
                              .read<FriendshipRepository>()
                              .sendFriendRequest(user.id),
                          'Friend request sent to ${user.name}.',
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Friends')),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Scrollable Request lists
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _loadData(showFullLoading: false),
                          child: NestedScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            headerSliverBuilder: (context, innerBoxIsScrolled) {
                              return [
                                SliverToBoxAdapter(
                                  child: Column(
                                    children: [
                                      _buildRequestList(
                                        list: _incomingRequests,
                                        title: 'Incoming Requests',
                                        emptyText:
                                            'No incoming friend requests.',
                                        actionBuilder: (user) => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 28,
                                              ),
                                              onPressed: () {
                                                _performAction(
                                                  () => context
                                                      .read<
                                                        FriendshipRepository
                                                      >()
                                                      .acceptFriendRequest(
                                                        user.id,
                                                      ),
                                                  'Request accepted!',
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.cancel_rounded,
                                                color: Colors.redAccent,
                                                size: 28,
                                              ),
                                              onPressed: () {
                                                _performAction(
                                                  () => context
                                                      .read<
                                                        FriendshipRepository
                                                      >()
                                                      .declineFriendRequest(
                                                        user.id,
                                                      ),
                                                  'Request declined.',
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildRequestList(
                                        list: _sentRequests,
                                        title: 'Requests Sent',
                                        emptyText: 'No pending requests sent.',
                                        actionBuilder: (user) => OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Colors.redAccent,
                                            ),
                                            foregroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            _performAction(
                                              () => context
                                                  .read<FriendshipRepository>()
                                                  .cancelFriendRequest(user.id),
                                              'Request cancelled.',
                                            );
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                            body: Column(
                              children: [
                                TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  indicatorColor: Colors.deepPurple,
                                  labelColor: Colors.deepPurple,
                                  unselectedLabelColor: Colors.grey,
                                  tabs: const [
                                    Tab(text: 'My Friends'),
                                    Tab(text: 'Discover New Friends'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildFriendsTab(),
                                      _buildDiscoverTab(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          if (_isActionInProgress)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
            ),
        ],
      ),
    );
  }
}
