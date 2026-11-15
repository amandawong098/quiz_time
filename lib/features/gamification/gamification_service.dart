import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/sound_service.dart';

enum CosmicItemCategory {
  hat,
  visor,
  windowTheme,
  gadget,
  avatarFrame,
  titleBadge,
}

enum CosmicItemRarity {
  common,
  rare,
  epic,
  legendary,
}

class CosmicShopItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int costXp;
  final CosmicItemCategory category;
  final CosmicItemRarity rarity;
  final List<Color> previewColors;

  const CosmicShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.costXp,
    required this.category,
    required this.rarity,
    this.previewColors = const [Color(0xFF7C4DFF), Color(0xFF311B92)],
  });

  String get rarityLabel {
    switch (rarity) {
      case CosmicItemRarity.common:
        return 'COMMON';
      case CosmicItemRarity.rare:
        return 'RARE';
      case CosmicItemRarity.epic:
        return 'EPIC';
      case CosmicItemRarity.legendary:
        return 'LEGENDARY';
    }
  }

  Color get rarityColor {
    switch (rarity) {
      case CosmicItemRarity.common:
        return const Color(0xFF38BDF8);
      case CosmicItemRarity.rare:
        return const Color(0xFFA855F7);
      case CosmicItemRarity.epic:
        return const Color(0xFFF59E0B);
      case CosmicItemRarity.legendary:
        return const Color(0xFFEC4899);
    }
  }
}

/// Represents a user's complete Cosmic Customization & Byte Space Cabin state.
/// Can be serialized to/from `public.profiles.customization`, `userMetadata`, and `SharedPreferences`.
class UserCosmicState {
  final int spentXp;
  final int bonusEarnedXp;
  final Set<String> unlockedIds;
  final String equippedHat;
  final String equippedVisor;
  final String equippedWindow;
  final Set<String> activeGadgets;
  final String equippedFrame;
  final String equippedTitle;
  final int byteEnergy; // 0..100
  final int byteBondXp; // Pet evolution XP
  final String? lastFreeFeedDate; // YYYY-MM-DD
  final int roomLikes;
  final Set<String> likedUserIds;
  final Map<String, int> dailyMissionProgress; // key -> count for today
  final Set<String> claimedDailyMissions; // missionId_YYYY-MM-DD
  final String? missionDate; // YYYY-MM-DD

  const UserCosmicState({
    this.spentXp = 0,
    this.bonusEarnedXp = 0,
    this.unlockedIds = const {
      'hat_none',
      'visor_cyan',
      'win_deep_space',
      'frame_default',
      'title_none',
    },
    this.equippedHat = 'hat_none',
    this.equippedVisor = 'visor_cyan',
    this.equippedWindow = 'win_deep_space',
    this.activeGadgets = const {},
    this.equippedFrame = 'frame_default',
    this.equippedTitle = 'title_none',
    this.byteEnergy = 75,
    this.byteBondXp = 0,
    this.lastFreeFeedDate,
    this.roomLikes = 0,
    this.likedUserIds = const {},
    this.dailyMissionProgress = const {},
    this.claimedDailyMissions = const {},
    this.missionDate,
  });

  int get byteStage {
    if (byteBondXp >= 120) return 3; // Hyper-Byte
    if (byteBondXp >= 45) return 2; // Astro-Byte
    return 1; // Mini-Byte
  }

  String get byteStageTitle {
    switch (byteStage) {
      case 3:
        return 'Stage 3 • Hyper-Byte';
      case 2:
        return 'Stage 2 • Astro-Byte';
      default:
        return 'Stage 1 • Mini-Byte';
    }
  }

  bool get isSupercharged => byteEnergy >= 80;

  UserCosmicState copyWith({
    int? spentXp,
    int? bonusEarnedXp,
    Set<String>? unlockedIds,
    String? equippedHat,
    String? equippedVisor,
    String? equippedWindow,
    Set<String>? activeGadgets,
    String? equippedFrame,
    String? equippedTitle,
    int? byteEnergy,
    int? byteBondXp,
    String? lastFreeFeedDate,
    int? roomLikes,
    Set<String>? likedUserIds,
    Map<String, int>? dailyMissionProgress,
    Set<String>? claimedDailyMissions,
    String? missionDate,
  }) {
    return UserCosmicState(
      spentXp: spentXp ?? this.spentXp,
      bonusEarnedXp: bonusEarnedXp ?? this.bonusEarnedXp,
      unlockedIds: unlockedIds ?? this.unlockedIds,
      equippedHat: equippedHat ?? this.equippedHat,
      equippedVisor: equippedVisor ?? this.equippedVisor,
      equippedWindow: equippedWindow ?? this.equippedWindow,
      activeGadgets: activeGadgets ?? this.activeGadgets,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      equippedTitle: equippedTitle ?? this.equippedTitle,
      byteEnergy: (byteEnergy ?? this.byteEnergy).clamp(0, 100),
      byteBondXp: byteBondXp ?? this.byteBondXp,
      lastFreeFeedDate: lastFreeFeedDate ?? this.lastFreeFeedDate,
      roomLikes: roomLikes ?? this.roomLikes,
      likedUserIds: likedUserIds ?? this.likedUserIds,
      dailyMissionProgress: dailyMissionProgress ?? this.dailyMissionProgress,
      claimedDailyMissions: claimedDailyMissions ?? this.claimedDailyMissions,
      missionDate: missionDate ?? this.missionDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spent_xp': spentXp,
      'bonus_earned_xp': bonusEarnedXp,
      'unlocked_ids': unlockedIds.toList(),
      'equipped_hat': equippedHat,
      'equipped_visor': equippedVisor,
      'equipped_window': equippedWindow,
      'active_gadgets': activeGadgets.toList(),
      'equipped_frame': equippedFrame,
      'equipped_title': equippedTitle,
      'byte_energy': byteEnergy,
      'byte_bond_xp': byteBondXp,
      'last_free_feed_date': lastFreeFeedDate,
      'room_likes': roomLikes,
      'liked_user_ids': likedUserIds.toList(),
      'daily_mission_progress': dailyMissionProgress,
      'claimed_daily_missions': claimedDailyMissions.toList(),
      'mission_date': missionDate,
    };
  }

  factory UserCosmicState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserCosmicState();
    final unlockedRaw = (json['unlocked_ids'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    unlockedRaw.addAll(const {
      'hat_none',
      'visor_cyan',
      'win_deep_space',
      'frame_default',
      'title_none',
    });

    final gadgetsRaw = (json['active_gadgets'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final likedRaw = (json['liked_user_ids'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final claimedRaw = (json['claimed_daily_missions'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final progressRaw = <String, int>{};
    if (json['daily_mission_progress'] is Map) {
      (json['daily_mission_progress'] as Map).forEach((k, v) {
        progressRaw[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    return UserCosmicState(
      spentXp: (json['spent_xp'] as num?)?.toInt() ?? 0,
      bonusEarnedXp: (json['bonus_earned_xp'] as num?)?.toInt() ?? 0,
      unlockedIds: unlockedRaw,
      equippedHat: json['equipped_hat'] as String? ?? 'hat_none',
      equippedVisor: json['equipped_visor'] as String? ?? 'visor_cyan',
      equippedWindow: json['equipped_window'] as String? ?? 'win_deep_space',
      activeGadgets: gadgetsRaw,
      equippedFrame: json['equipped_frame'] as String? ?? 'frame_default',
      equippedTitle: json['equipped_title'] as String? ?? 'title_none',
      byteEnergy: ((json['byte_energy'] as num?)?.toInt() ?? 75).clamp(0, 100),
      byteBondXp: (json['byte_bond_xp'] as num?)?.toInt() ?? 0,
      lastFreeFeedDate: json['last_free_feed_date'] as String?,
      roomLikes: (json['room_likes'] as num?)?.toInt() ?? 0,
      likedUserIds: likedRaw,
      dailyMissionProgress: progressRaw,
      claimedDailyMissions: claimedRaw,
      missionDate: json['mission_date'] as String?,
    );
  }
}

class DailyMissionSpec {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final int targetCount;
  final int rewardXp;

  const DailyMissionSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.targetCount,
    required this.rewardXp,
  });
}

class MysteryPodResult {
  final CosmicShopItem item;
  final bool wasDuplicate;
  final int duplicateBonusXp;

  const MysteryPodResult({
    required this.item,
    required this.wasDuplicate,
    this.duplicateBonusXp = 0,
  });
}

class GamificationService extends ChangeNotifier {
  GamificationService._internal();
  static final GamificationService instance = GamificationService._internal();

  static const int mysteryPodCostXp = 60;
  static const int energizeByteCostXp = 15;

  static const List<DailyMissionSpec> dailyMissions = [
    DailyMissionSpec(
      id: 'study_complete',
      title: 'Cosmic Explorer',
      subtitle: 'Complete 1 Quiz or Lesson today',
      emoji: '🚀',
      targetCount: 1,
      rewardXp: 30,
    ),
    DailyMissionSpec(
      id: 'care_byte',
      title: 'Byte Caretaker',
      subtitle: 'Energize or play with Byte in the Space Cabin',
      emoji: '🔋',
      targetCount: 1,
      rewardXp: 25,
    ),
    DailyMissionSpec(
      id: 'social_or_style',
      title: 'Galactic Stylist',
      subtitle: 'Equip an item or High-Five a friend\'s Byte',
      emoji: '✨',
      targetCount: 1,
      rewardXp: 25,
    ),
  ];

  static const List<CosmicShopItem> catalog = [
    // ---------------- HATS ----------------
    CosmicShopItem(
      id: 'hat_none',
      name: 'Classic Antenna',
      description: 'Byte\'s standard starlight signal antenna.',
      emoji: '📡',
      costXp: 0,
      category: CosmicItemCategory.hat,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF64748B), Color(0xFF334155)],
    ),
    CosmicShopItem(
      id: 'hat_astro',
      name: 'Orbit Halo Ring',
      description: 'A levitating golden planetary halo above Byte.',
      emoji: '🪐',
      costXp: 50,
      category: CosmicItemCategory.hat,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    ),
    CosmicShopItem(
      id: 'hat_grad',
      name: 'Scholar Mortarboard',
      description: 'Official graduation cap of the Stellar Academy.',
      emoji: '🎓',
      costXp: 70,
      category: CosmicItemCategory.hat,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFF6366F1), Color(0xFF312E81)],
    ),
    CosmicShopItem(
      id: 'hat_crown',
      name: 'Starlight Crown',
      description: 'Forged from pure supernova gold for top scholars.',
      emoji: '👑',
      costXp: 90,
      category: CosmicItemCategory.hat,
      rarity: CosmicItemRarity.epic,
      previewColors: [Color(0xFFFBBF24), Color(0xFFB45309)],
    ),
    CosmicShopItem(
      id: 'hat_headphones',
      name: 'Cyber DJ Headset',
      description: 'Glowing neon stereo headphones pulsing with beats.',
      emoji: '🎧',
      costXp: 95,
      category: CosmicItemCategory.hat,
      rarity: CosmicItemRarity.epic,
      previewColors: [Color(0xFFEC4899), Color(0xFF7E22CE)],
    ),
    CosmicShopItem(
      id: 'hat_wizard',
      name: 'Nebula Mage Hat',
      description: 'Mystical cosmic spire hat embroidered with stars.',
      emoji: '🧙',
      costXp: 130,
      category: CosmicItemCategory.hat,
      rarity: CosmicItemRarity.legendary,
      previewColors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
    ),

    // ---------------- VISORS ----------------
    CosmicShopItem(
      id: 'visor_cyan',
      name: 'Aqua Core Visor',
      description: 'Default friendly cyan LED eyes & starlight core.',
      emoji: '🩵',
      costXp: 0,
      category: CosmicItemCategory.visor,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
    ),
    CosmicShopItem(
      id: 'visor_gold',
      name: 'Solar Gold Visor',
      description: 'Radiant golden eyes powered by solar flares.',
      emoji: '💛',
      costXp: 45,
      category: CosmicItemCategory.visor,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFFFFD54F), Color(0xFFF59E0B)],
    ),
    CosmicShopItem(
      id: 'visor_magenta',
      name: 'Pink Nebula Visor',
      description: 'Vibrant neon rose-pink cybernetic expression.',
      emoji: '🩷',
      costXp: 65,
      category: CosmicItemCategory.visor,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFFF472B6), Color(0xFFDB2777)],
    ),
    CosmicShopItem(
      id: 'visor_emerald',
      name: 'Emerald Matrix Visor',
      description: 'High-tech hacker green digital visor glow.',
      emoji: '💚',
      costXp: 65,
      category: CosmicItemCategory.visor,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFF34D399), Color(0xFF059669)],
    ),
    CosmicShopItem(
      id: 'visor_rainbow',
      name: 'Hypernova Prism Core',
      description: 'Legendary dual-tone violet & cyan plasma core.',
      emoji: '🌈',
      costXp: 120,
      category: CosmicItemCategory.visor,
      rarity: CosmicItemRarity.legendary,
      previewColors: [Color(0xFFE879F9), Color(0xFF38BDF8)],
    ),

    // ---------------- CABIN WINDOWS ----------------
    CosmicShopItem(
      id: 'win_deep_space',
      name: 'Deep Nebula Orbit',
      description: 'Serene indigo starfield outside your cabin window.',
      emoji: '🌌',
      costXp: 0,
      category: CosmicItemCategory.windowTheme,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
    ),
    CosmicShopItem(
      id: 'win_mars',
      name: 'Crimson Mars Colony',
      description: 'Warm red Martian horizon with twin moons.',
      emoji: '🔴',
      costXp: 70,
      category: CosmicItemCategory.windowTheme,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF991B1B), Color(0xFF450A0A)],
    ),
    CosmicShopItem(
      id: 'win_saturn',
      name: 'Saturn Ring Vista',
      description: 'Breathtaking golden gas giant rings outside.',
      emoji: '🪐',
      costXp: 100,
      category: CosmicItemCategory.windowTheme,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFF78350F), Color(0xFF1E1B4B)],
    ),
    CosmicShopItem(
      id: 'win_cyber',
      name: 'Synthwave Grid Sector',
      description: 'Neon magenta & cyan cyber-grid horizon.',
      emoji: '🌆',
      costXp: 125,
      category: CosmicItemCategory.windowTheme,
      rarity: CosmicItemRarity.epic,
      previewColors: [Color(0xFF701A75), Color(0xFF0F172A)],
    ),
    CosmicShopItem(
      id: 'win_supernova',
      name: 'Supernova Aurora',
      description: 'Dazzling emerald & violet galactic aurora borealis.',
      emoji: '✨',
      costXp: 155,
      category: CosmicItemCategory.windowTheme,
      rarity: CosmicItemRarity.legendary,
      previewColors: [Color(0xFF065F46), Color(0xFF3B0764)],
    ),

    // ---------------- INTERACTIVE GADGETS ----------------
    CosmicShopItem(
      id: 'gad_lava_lamp',
      name: 'Zero-G Plasma Lamp',
      description: 'Floating glowing plasma bubbles—tap to bubble!',
      emoji: '🧪',
      costXp: 50,
      category: CosmicItemCategory.gadget,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    ),
    CosmicShopItem(
      id: 'gad_hologram',
      name: '3D Star Hologram',
      description: 'Interactive rotating holographic galaxy projector.',
      emoji: '🌐',
      costXp: 80,
      category: CosmicItemCategory.gadget,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFF00E5FF), Color(0xFF1D4ED8)],
    ),
    CosmicShopItem(
      id: 'gad_arcade',
      name: 'Retro Cosmic Arcade',
      description: 'Mini chiptune arcade cabinet—tap to play a tune!',
      emoji: '🕹️',
      costXp: 110,
      category: CosmicItemCategory.gadget,
      rarity: CosmicItemRarity.epic,
      previewColors: [Color(0xFFF59E0B), Color(0xFF7C3AED)],
    ),
    CosmicShopItem(
      id: 'gad_robopet',
      name: 'Astro-Pup Companion',
      description: 'A tiny floating robo-puppy friend for Byte!',
      emoji: '🐾',
      costXp: 145,
      category: CosmicItemCategory.gadget,
      rarity: CosmicItemRarity.legendary,
      previewColors: [Color(0xFFF43F5E), Color(0xFFFBBF24)],
    ),

    // ---------------- AVATAR FRAMES ----------------
    CosmicShopItem(
      id: 'frame_default',
      name: 'Classic Starlight',
      description: 'Standard golden starlight profile ring.',
      emoji: '⭕',
      costXp: 0,
      category: CosmicItemCategory.avatarFrame,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFFFFD54F), Color(0xFF5E35B1)],
    ),
    CosmicShopItem(
      id: 'frame_orbit',
      name: 'Cyan Pulsar Ring',
      description: 'Dual electric-cyan orbital rings around your avatar.',
      emoji: '💠',
      costXp: 65,
      category: CosmicItemCategory.avatarFrame,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
    ),
    CosmicShopItem(
      id: 'frame_neon',
      name: 'Magenta Cyber Halo',
      description: 'Glowing neon pink-violet synthwave avatar border.',
      emoji: '🔮',
      costXp: 90,
      category: CosmicItemCategory.avatarFrame,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFFF472B6), Color(0xFF9333EA)],
    ),
    CosmicShopItem(
      id: 'frame_plasma',
      name: 'Emerald Nova Aura',
      description: 'Radiant aurora-green energy shield border.',
      emoji: '❇️',
      costXp: 115,
      category: CosmicItemCategory.avatarFrame,
      rarity: CosmicItemRarity.epic,
      previewColors: [Color(0xFF34D399), Color(0xFF059669)],
    ),
    CosmicShopItem(
      id: 'frame_supernova',
      name: 'Supernova Sovereign',
      description: 'Legendary rainbow-gold cosmic crown avatar border.',
      emoji: '👑',
      costXp: 160,
      category: CosmicItemCategory.avatarFrame,
      rarity: CosmicItemRarity.legendary,
      previewColors: [Color(0xFFFBBF24), Color(0xFFEC4899)],
    ),

    // ---------------- COSMIC TITLES ----------------
    CosmicShopItem(
      id: 'title_none',
      name: 'No Title Badge',
      description: 'Display your name without a title badge.',
      emoji: '➖',
      costXp: 0,
      category: CosmicItemCategory.titleBadge,
      rarity: CosmicItemRarity.common,
    ),
    CosmicShopItem(
      id: 'title_pioneer',
      name: '🚀 Galactic Pioneer',
      description: 'Displayed under your name on Profile & Leaderboards.',
      emoji: '🚀',
      costXp: 40,
      category: CosmicItemCategory.titleBadge,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFF38BDF8), Color(0xFF1D4ED8)],
    ),
    CosmicShopItem(
      id: 'title_quiz_whiz',
      name: '⚡ Quiz Whiz',
      description: 'Show off your lightning-fast quiz reflexes.',
      emoji: '⚡',
      costXp: 60,
      category: CosmicItemCategory.titleBadge,
      rarity: CosmicItemRarity.common,
      previewColors: [Color(0xFFFBBF24), Color(0xFFD97706)],
    ),
    CosmicShopItem(
      id: 'title_scholar',
      name: '🧠 Stellar Genius',
      description: 'A badge of honor for dedicated knowledge seekers.',
      emoji: '🧠',
      costXp: 85,
      category: CosmicItemCategory.titleBadge,
      rarity: CosmicItemRarity.rare,
      previewColors: [Color(0xFFA855F7), Color(0xFF6D28D9)],
    ),
    CosmicShopItem(
      id: 'title_voyager',
      name: '🛸 Nebula Commander',
      description: 'Command respect across every discussion & lobby.',
      emoji: '🛸',
      costXp: 110,
      category: CosmicItemCategory.titleBadge,
      rarity: CosmicItemRarity.epic,
      previewColors: [Color(0xFFEC4899), Color(0xFFBE185D)],
    ),
    CosmicShopItem(
      id: 'title_legend',
      name: '👑 Cosmic Overlord',
      description: 'The ultimate title for masters of the universe.',
      emoji: '👑',
      costXp: 150,
      category: CosmicItemCategory.titleBadge,
      rarity: CosmicItemRarity.legendary,
      previewColors: [Color(0xFFF59E0B), Color(0xFFDC2626)],
    ),
  ];

  static CosmicShopItem? itemById(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  UserCosmicState _state = const UserCosmicState();
  UserCosmicState get state => _state;

  int _lifetimeXp = 0;
  int get lifetimeXp => _lifetimeXp;

  /// Spendable XP = Lifetime XP + Bonus Mission/Pod XP - Spent XP
  int get spendableXp =>
      max(0, _lifetimeXp + _state.bonusEarnedXp - _state.spentXp);

  /// 1.5x XP multiplier when Byte's energy is >= 80%
  double get xpMultiplier => _state.isSupercharged ? 1.5 : 1.0;

  String? _loadedUserId;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadForCurrentUser({int? knownLifetimeXp}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    if (knownLifetimeXp != null) {
      _lifetimeXp = knownLifetimeXp;
    }

    _isLoading = true;
    _loadedUserId = user.id;

    Map<String, dynamic>? loadedJson;

    // 1. Try reading from SharedPreferences cache first for instant UI
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cosmic_state_${user.id}');
      if (raw != null && raw.isNotEmpty) {
        loadedJson = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    // 2. Try reading from public.profiles (xp + optional customization column)
    try {
      final profileRow = await client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      if (profileRow != null) {
        _lifetimeXp = (profileRow['xp'] as num?)?.toInt() ?? _lifetimeXp;
        if (profileRow['customization'] is Map) {
          loadedJson = Map<String, dynamic>.from(
            profileRow['customization'] as Map,
          );
        }
      }
    } catch (_) {}

    // 3. Fallback to auth.users userMetadata['cosmic_customization']
    if (loadedJson == null) {
      final meta = user.userMetadata;
      if (meta != null) {
        if (_lifetimeXp == 0 && meta['xp'] != null) {
          _lifetimeXp = int.tryParse(meta['xp'].toString()) ?? 0;
        }
        if (meta['cosmic_customization'] is Map) {
          loadedJson = Map<String, dynamic>.from(
            meta['cosmic_customization'] as Map,
          );
        }
      }
    }

    var parsed = UserCosmicState.fromJson(loadedJson);
    // Reset daily mission progress if date changed
    if (parsed.missionDate != _todayKey) {
      parsed = parsed.copyWith(
        dailyMissionProgress: {},
        missionDate: _todayKey,
      );
    }

    _state = parsed;
    _isLoading = false;
    notifyListeners();
  }

  void syncLifetimeXp(int xp) {
    if (_lifetimeXp != xp) {
      _lifetimeXp = xp;
      notifyListeners();
    }
  }

  Future<void> _persistState() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final jsonMap = _state.toJson();

    // 1. Save to SharedPreferences immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cosmic_state_${user.id}', jsonEncode(jsonMap));
    } catch (_) {}

    // 2. Save to public.profiles.customization (if column exists)
    try {
      await client
          .from('profiles')
          .update({'customization': jsonMap})
          .eq('id', user.id);
    } catch (_) {
      // Gracefully ignore if user hasn't run the 1-line SQL migration yet
    }

    // 3. Also save to userMetadata so it persists in cloud even without SQL migration
    try {
      final currentMeta = user.userMetadata ?? {};
      await client.auth.updateUser(
        UserAttributes(
          data: {
            ...currentMeta,
            'cosmic_customization': jsonMap,
          },
        ),
      );
    } catch (_) {}
  }

  /// Fetch another user's Cosmic State for Social Room Visiting & Profile Flair.
  Future<UserCosmicState> fetchUserCosmicState(String targetUserId) async {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (targetUserId == currentUid && _loadedUserId == currentUid) {
      return _state;
    }
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', targetUserId)
          .maybeSingle();
      if (row != null && row['customization'] is Map) {
        return UserCosmicState.fromJson(
          Map<String, dynamic>.from(row['customization'] as Map),
        );
      }
    } catch (_) {}
    return const UserCosmicState();
  }

  /// Purchase and immediately equip an item from the Cosmic Shop.
  Future<bool> purchaseItem(CosmicShopItem item) async {
    if (_state.unlockedIds.contains(item.id)) {
      await equipItem(item);
      return true;
    }
    if (spendableXp < item.costXp) {
      return false;
    }

    final newUnlocked = Set<String>.from(_state.unlockedIds)..add(item.id);
    _state = _state.copyWith(
      spentXp: _state.spentXp + item.costXp,
      unlockedIds: newUnlocked,
    );
    await equipItem(item, persist: false);
    _incrementMissionProgress('social_or_style');
    SoundService.instance.playCorrectAnswer();
    notifyListeners();
    await _persistState();
    return true;
  }

  /// Equip an already-unlocked item (or toggle a room gadget).
  Future<void> equipItem(CosmicShopItem item, {bool persist = true}) async {
    if (!_state.unlockedIds.contains(item.id)) return;

    switch (item.category) {
      case CosmicItemCategory.hat:
        _state = _state.copyWith(equippedHat: item.id);
        break;
      case CosmicItemCategory.visor:
        _state = _state.copyWith(equippedVisor: item.id);
        break;
      case CosmicItemCategory.windowTheme:
        _state = _state.copyWith(equippedWindow: item.id);
        break;
      case CosmicItemCategory.gadget:
        final nextGadgets = Set<String>.from(_state.activeGadgets);
        if (nextGadgets.contains(item.id)) {
          nextGadgets.remove(item.id);
        } else {
          nextGadgets.add(item.id);
        }
        _state = _state.copyWith(activeGadgets: nextGadgets);
        break;
      case CosmicItemCategory.avatarFrame:
        _state = _state.copyWith(equippedFrame: item.id);
        break;
      case CosmicItemCategory.titleBadge:
        _state = _state.copyWith(equippedTitle: item.id);
        break;
    }

    _incrementMissionProgress('social_or_style');
    if (persist) {
      SoundService.instance.playOptionSelect();
      notifyListeners();
      await _persistState();
    }
  }

  /// Spin the Mystery Star-Pod (Gacha mini-game).
  Future<MysteryPodResult?> spinMysteryPod() async {
    if (spendableXp < mysteryPodCostXp) return null;

    final rng = Random();
    final paidItems = catalog.where((i) => i.costXp > 0).toList();
    final unownedItems =
        paidItems.where((i) => !_state.unlockedIds.contains(i.id)).toList();

    // 85% chance to prioritize an unowned item if any remain
    final pool = (unownedItems.isNotEmpty && rng.nextDouble() < 0.85)
        ? unownedItems
        : paidItems;

    // Weight by rarity
    final weighted = <CosmicShopItem>[];
    for (final item in pool) {
      final weight = switch (item.rarity) {
        CosmicItemRarity.common => 4,
        CosmicItemRarity.rare => 3,
        CosmicItemRarity.epic => 2,
        CosmicItemRarity.legendary => 1,
      };
      for (int k = 0; k < weight; k++) {
        weighted.add(item);
      }
    }

    final chosen = weighted[rng.nextInt(weighted.length)];
    final alreadyOwned = _state.unlockedIds.contains(chosen.id);

    if (alreadyOwned) {
      // Duplicate protection: refund 75 Bonus XP (+15 net gain!)
      const jackpotXp = 75;
      _state = _state.copyWith(
        spentXp: _state.spentXp + mysteryPodCostXp,
        bonusEarnedXp: _state.bonusEarnedXp + jackpotXp,
      );
      SoundService.instance.playQuizComplete();
      notifyListeners();
      await _persistState();
      return MysteryPodResult(
        item: chosen,
        wasDuplicate: true,
        duplicateBonusXp: jackpotXp,
      );
    } else {
      final nextUnlocked = Set<String>.from(_state.unlockedIds)..add(chosen.id);
      _state = _state.copyWith(
        spentXp: _state.spentXp + mysteryPodCostXp,
        unlockedIds: nextUnlocked,
      );
      await equipItem(chosen, persist: false);
      SoundService.instance.playQuizComplete();
      notifyListeners();
      await _persistState();
      return MysteryPodResult(
        item: chosen,
        wasDuplicate: false,
      );
    }
  }

  bool get canFreeFeedToday => _state.lastFreeFeedDate != _todayKey;

  /// Feed / Energize Byte in the Space Cabin.
  /// Free once per day, or costs 15 Spendable XP for extra Super-Charge cells.
  Future<({bool success, String message})> energizeByte() async {
    final isFree = canFreeFeedToday;
    if (!isFree && spendableXp < energizeByteCostXp) {
      return (
        success: false,
        message: 'Need $energizeByteCostXp Spendable XP for a Super-Charge Cell!',
      );
    }

    final newEnergy = (_state.byteEnergy + 25).clamp(0, 100);
    final newBond = _state.byteBondXp + 15;

    _state = _state.copyWith(
      spentXp: isFree ? _state.spentXp : _state.spentXp + energizeByteCostXp,
      byteEnergy: newEnergy,
      byteBondXp: newBond,
      lastFreeFeedDate: _todayKey,
    );
    _incrementMissionProgress('care_byte');
    SoundService.instance.playCorrectAnswer();
    notifyListeners();
    await _persistState();

    final boostNote = newEnergy >= 80
        ? ' ⚡ Byte is SUPERCHARGED (1.5x XP Boost Active)!'
        : '';
    return (
      success: true,
      message: isFree
          ? 'Fed Byte a free Daily Starlight Snack! (+25% Energy, +15 Bond)$boostNote'
          : 'Charged Byte with a Super-Cell! (+25% Energy, +15 Bond)$boostNote',
    );
  }

  /// Free interactive play action inside Byte's Space Cabin.
  Future<String> playWithByte() async {
    final newEnergy = (_state.byteEnergy + 10).clamp(0, 100);
    final newBond = _state.byteBondXp + 5;
    _state = _state.copyWith(
      byteEnergy: newEnergy,
      byteBondXp: newBond,
    );
    _incrementMissionProgress('care_byte');
    SoundService.instance.playMascotChirp();
    notifyListeners();
    await _persistState();
    return newEnergy >= 80
        ? 'Byte loved the cosmic tune! ⚡ 1.5x XP Boost is active!'
        : 'Byte danced to the cosmic tune! (+10% Energy, +5 Bond)';
  }

  /// Record that the user completed a Quiz or Lesson today (for Daily Mission).
  Future<void> recordStudyCompletion() async {
    _incrementMissionProgress('study_complete');
    notifyListeners();
    await _persistState();
  }

  void _incrementMissionProgress(String missionId) {
    final currentDate = _todayKey;
    final baseMap = _state.missionDate == currentDate
        ? Map<String, int>.from(_state.dailyMissionProgress)
        : <String, int>{};
    baseMap[missionId] = (baseMap[missionId] ?? 0) + 1;
    _state = _state.copyWith(
      dailyMissionProgress: baseMap,
      missionDate: currentDate,
    );
  }

  int getMissionProgress(String missionId) {
    if (_state.missionDate != _todayKey) return 0;
    return _state.dailyMissionProgress[missionId] ?? 0;
  }

  bool isMissionClaimedToday(String missionId) {
    return _state.claimedDailyMissions.contains('${missionId}_$_todayKey');
  }

  Future<bool> claimDailyMission(DailyMissionSpec spec) async {
    final progress = getMissionProgress(spec.id);
    final claimKey = '${spec.id}_$_todayKey';
    if (progress < spec.targetCount ||
        _state.claimedDailyMissions.contains(claimKey)) {
      return false;
    }

    final nextClaimed = Set<String>.from(_state.claimedDailyMissions)
      ..add(claimKey);
    _state = _state.copyWith(
      bonusEarnedXp: _state.bonusEarnedXp + spec.rewardXp,
      byteBondXp: _state.byteBondXp + 10,
      claimedDailyMissions: nextClaimed,
    );
    SoundService.instance.playQuizComplete();
    notifyListeners();
    await _persistState();
    return true;
  }

  /// High-Five another user's Byte when visiting their Space Cabin!
  Future<({bool success, int newLikes, String message})> highFiveUserRoom({
    required String targetUserId,
    required UserCosmicState currentTargetState,
  }) async {
    if (_state.likedUserIds.contains(targetUserId)) {
      return (
        success: false,
        newLikes: currentTargetState.roomLikes,
        message: 'You already sent a High-Five to this Space Cabin!',
      );
    }

    final updatedTargetLikes = currentTargetState.roomLikes + 1;
    final updatedTargetState =
        currentTargetState.copyWith(roomLikes: updatedTargetLikes);

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'customization': updatedTargetState.toJson()})
          .eq('id', targetUserId);
    } catch (_) {}

    final nextLiked = Set<String>.from(_state.likedUserIds)..add(targetUserId);
    _state = _state.copyWith(
      likedUserIds: nextLiked,
      bonusEarnedXp: _state.bonusEarnedXp + 10,
    );
    _incrementMissionProgress('social_or_style');
    SoundService.instance.playCorrectAnswer();
    notifyListeners();
    await _persistState();

    return (
      success: true,
      newLikes: updatedTargetLikes,
      message: '👋 High-Five sent! You also earned +10 Bonus Spendable XP!',
    );
  }
}
