import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/byte_mascot.dart';

enum CosmicItemCategory {
  costume, // Full Vector Costumes (Astronaut, Alien, Planet, Wizard, Ninja, Royalty)
  body,    // Body & Helmet Armor Paint
  eye,     // Visor Eye Style & Color
  stage,   // Game Stage & Avatar Backdrop World
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
  final CosmicItemCategory category;
  final CosmicItemRarity rarity;
  final int costXp;
  final Color primaryColor;
  final Color secondaryColor;

  const CosmicShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.costXp,
    required this.primaryColor,
    required this.secondaryColor,
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
        return const Color(0xFF94A3B8);
      case CosmicItemRarity.rare:
        return const Color(0xFF38BDF8);
      case CosmicItemRarity.epic:
        return const Color(0xFFC084FC);
      case CosmicItemRarity.legendary:
        return const Color(0xFFFACC15);
    }
  }

  /// Creates a preview `ByteAppearance` showing this item applied on top of `base`.
  ByteAppearance previewOn(ByteAppearance base) {
    switch (category) {
      case CosmicItemCategory.costume:
        return base.copyWith(costumeId: id);
      case CosmicItemCategory.body:
        return base.copyWith(bodyId: id);
      case CosmicItemCategory.eye:
        return base.copyWith(eyeId: id);
      case CosmicItemCategory.stage:
        return base.copyWith(stageId: id);
    }
  }
}

class UserCosmicState {
  static const List<String> starterItemIds = [
    'costume_none',
    'body_classic',
    'eye_cyan',
    'stage_nebula',
  ];

  final int spentXp;
  final int bonusXpEarned;
  final List<String> ownedItems;
  final String equippedCostume;
  final String equippedBody;
  final String equippedEye;
  final String equippedStage;

  const UserCosmicState({
    this.spentXp = 0,
    this.bonusXpEarned = 0,
    this.ownedItems = starterItemIds,
    this.equippedCostume = 'costume_none',
    this.equippedBody = 'body_classic',
    this.equippedEye = 'eye_cyan',
    this.equippedStage = 'stage_nebula',
  });

  ByteAppearance get appearance => ByteAppearance(
        bodyId: equippedBody,
        eyeId: equippedEye,
        costumeId: equippedCostume,
        stageId: equippedStage,
      );

  /// Number of paid/unlockable wardrobe items the user owns (excludes the 4 free starters).
  int get unlockedPaidCount =>
      ownedItems.where((id) => !starterItemIds.contains(id)).length;

  /// Option B: Wardrobe Collection Milestone Quiz XP Multiplier.
  /// Owning more Byte customization items grants a permanent passive Quiz XP Boost
  /// regardless of which outfit you currently wear.
  double get quizXpMultiplier {
    final c = unlockedPaidCount;
    if (c >= 14) return 1.5;
    if (c >= 9) return 1.3;
    if (c >= 5) return 1.2;
    if (c >= 2) return 1.1;
    return 1.0;
  }

  int get boostPercent => ((quizXpMultiplier - 1.0) * 100).round();

  int? get nextBoostThreshold {
    final c = unlockedPaidCount;
    if (c < 2) return 2;
    if (c < 5) return 5;
    if (c < 9) return 9;
    if (c < 14) return 14;
    return null;
  }

  double get boostProgress {
    final c = unlockedPaidCount;
    if (c >= 14) return 1.0;
    if (c >= 9) return (c - 9) / 5.0;
    if (c >= 5) return (c - 5) / 4.0;
    if (c >= 2) return (c - 2) / 3.0;
    return c / 2.0;
  }

  bool get hasActiveBoost => quizXpMultiplier > 1.0;

  UserCosmicState copyWith({
    int? spentXp,
    int? bonusXpEarned,
    List<String>? ownedItems,
    String? equippedCostume,
    String? equippedBody,
    String? equippedEye,
    String? equippedStage,
  }) {
    return UserCosmicState(
      spentXp: spentXp ?? this.spentXp,
      bonusXpEarned: bonusXpEarned ?? this.bonusXpEarned,
      ownedItems: ownedItems ?? this.ownedItems,
      equippedCostume: equippedCostume ?? this.equippedCostume,
      equippedBody: equippedBody ?? this.equippedBody,
      equippedEye: equippedEye ?? this.equippedEye,
      equippedStage: equippedStage ?? this.equippedStage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spentXp': spentXp,
      'bonusXpEarned': bonusXpEarned,
      'ownedItems': ownedItems,
      'equippedCostume': equippedCostume,
      'equippedBody': equippedBody,
      'equippedEye': equippedEye,
      'equippedStage': equippedStage,
    };
  }

  factory UserCosmicState.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const UserCosmicState();

    List<String> parseStringList(dynamic raw, List<String> fallback) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return fallback;
    }

    final owned = parseStringList(json['ownedItems'], List<String>.from(starterItemIds));
    for (final starter in starterItemIds) {
      if (!owned.contains(starter)) owned.add(starter);
    }

    return UserCosmicState(
      spentXp: (json['spentXp'] as num?)?.toInt() ?? 0,
      bonusXpEarned: (json['bonusXpEarned'] as num?)?.toInt() ?? 0,
      ownedItems: owned,
      equippedCostume: json['equippedCostume'] as String? ?? 'costume_none',
      equippedBody: json['equippedBody'] as String? ?? 'body_classic',
      equippedEye: json['equippedEye'] as String? ?? 'eye_cyan',
      equippedStage: json['equippedStage'] as String? ?? 'stage_nebula',
    );
  }
}

class GamificationService extends ChangeNotifier {
  static final GamificationService instance = GamificationService._internal();
  GamificationService._internal();

  UserCosmicState _state = const UserCosmicState();
  int _lifetimeXp = 0;
  bool _isLoaded = false;

  UserCosmicState get state => _state;
  int get lifetimeXp => _lifetimeXp;
  bool get isLoaded => _isLoaded;

  /// Spendable XP = Lifetime XP + any legacy Bonus XP - Spent XP.
  /// Spending XP in the Byte Studio NEVER lowers Leaderboard XP!
  int get spendableXp =>
      max(0, _lifetimeXp + _state.bonusXpEarned - _state.spentXp);

  double get xpMultiplier => _state.quizXpMultiplier;

  // ===========================================================================
  // FULL VECTOR AVATAR & STAGE SHOP CATALOG
  // ===========================================================================
  static const List<CosmicShopItem> catalog = [
    // --- 1. FITTED COSTUMES ---
    CosmicShopItem(
      id: 'costume_none',
      name: 'Astro-Bot',
      description: 'Byte\'s classic deep-space explorer chassis.',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.common,
      costXp: 0,
      primaryColor: Color(0xFF7E57C2),
      secondaryColor: Color(0xFFD1C4E9),
    ),
    CosmicShopItem(
      id: 'costume_astronaut',
      name: 'Commander Suit',
      description: 'Gold visor seal, chest telemetry box & dual flame jetpack!',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.rare,
      costXp: 50,
      primaryColor: Color(0xFF38BDF8),
      secondaryColor: Color(0xFFF59E0B),
    ),
    CosmicShopItem(
      id: 'costume_alien',
      name: 'Martian Disguise',
      description: 'Three glowing alien eyes, dual feelers & UFO saucer belt!',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.rare,
      costXp: 70,
      primaryColor: Color(0xFF00E676),
      secondaryColor: Color(0xFF76FF03),
    ),
    CosmicShopItem(
      id: 'costume_planet',
      name: 'Saturn Planet',
      description: '3D orbiting planetary rings & an icy moon around Byte!',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.epic,
      costXp: 95,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFF38BDF8),
    ),
    CosmicShopItem(
      id: 'costume_wizard',
      name: 'Starlight Wizard',
      description: 'Pointed star hat, flowing mystic cape & glowing star wand!',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.epic,
      costXp: 110,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFFBBF24),
    ),
    CosmicShopItem(
      id: 'costume_cyber_ninja',
      name: 'Cyber-Shinobi',
      description: 'Fluttering headband, dual plasma katanas & neon shuriken!',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.epic,
      costXp: 130,
      primaryColor: Color(0xFFF43F5E),
      secondaryColor: Color(0xFF00E5FF),
    ),
    CosmicShopItem(
      id: 'costume_royalty',
      name: 'Galactic Royalty',
      description: 'Jewelled gold crown, crimson ermine cape & royal scepter!',
      category: CosmicItemCategory.costume,
      rarity: CosmicItemRarity.legendary,
      costXp: 160,
      primaryColor: Color(0xFFFACC15),
      secondaryColor: Color(0xFFE11D48),
    ),

    // --- 2. BODY PAINTS ---
    CosmicShopItem(
      id: 'body_classic',
      name: 'Starlight White',
      description: 'Crisp ceramic white with lavender trim.',
      category: CosmicItemCategory.body,
      rarity: CosmicItemRarity.common,
      costXp: 0,
      primaryColor: Color(0xFFEDE7F6),
      secondaryColor: Color(0xFF7E57C2),
    ),
    CosmicShopItem(
      id: 'body_rose',
      name: 'Rose Quartz',
      description: 'Pastel nebula pink metallic finish.',
      category: CosmicItemCategory.body,
      rarity: CosmicItemRarity.common,
      costXp: 35,
      primaryColor: Color(0xFFF472B6),
      secondaryColor: Color(0xFFDB2777),
    ),
    CosmicShopItem(
      id: 'body_emerald',
      name: 'Bio-Plasma Mint',
      description: 'Luminous emerald-mint alloy coat.',
      category: CosmicItemCategory.body,
      rarity: CosmicItemRarity.common,
      costXp: 40,
      primaryColor: Color(0xFF34D399),
      secondaryColor: Color(0xFF059669),
    ),
    CosmicShopItem(
      id: 'body_obsidian',
      name: 'Stealth Obsidian',
      description: 'Matte carbon-black armor with neon cyan trim.',
      category: CosmicItemCategory.body,
      rarity: CosmicItemRarity.rare,
      costXp: 55,
      primaryColor: Color(0xFF1E293B),
      secondaryColor: Color(0xFF00E5FF),
    ),
    CosmicShopItem(
      id: 'body_galaxy',
      name: 'Cosmic Indigo',
      description: 'Deep space violet with electric magenta edges.',
      category: CosmicItemCategory.body,
      rarity: CosmicItemRarity.epic,
      costXp: 75,
      primaryColor: Color(0xFF6D28D9),
      secondaryColor: Color(0xFFE879F9),
    ),
    CosmicShopItem(
      id: 'body_gold',
      name: 'Solar Gold',
      description: '24K Championship gold-plated cosmic armor!',
      category: CosmicItemCategory.body,
      rarity: CosmicItemRarity.legendary,
      costXp: 120,
      primaryColor: Color(0xFFFACC15),
      secondaryColor: Color(0xFFB45309),
    ),

    // --- 3. VISOR EYES ---
    CosmicShopItem(
      id: 'eye_cyan',
      name: 'Cyber Cyan',
      description: 'Classic glowing cyan LED visor eyes.',
      category: CosmicItemCategory.eye,
      rarity: CosmicItemRarity.common,
      costXp: 0,
      primaryColor: Color(0xFF64FFDA),
      secondaryColor: Color(0xFF00BFA5),
    ),
    CosmicShopItem(
      id: 'eye_fire_amber',
      name: 'Blazing Hero',
      description: 'Determined fiery orange mecha eyes!',
      category: CosmicItemCategory.eye,
      rarity: CosmicItemRarity.common,
      costXp: 35,
      primaryColor: Color(0xFFFF9100),
      secondaryColor: Color(0xFFFF3D00),
    ),
    CosmicShopItem(
      id: 'eye_emerald_pixel',
      name: '8-Bit Pixel',
      description: 'Retro arcade blocky matrix green eyes.',
      category: CosmicItemCategory.eye,
      rarity: CosmicItemRarity.rare,
      costXp: 45,
      primaryColor: Color(0xFF00E676),
      secondaryColor: Color(0xFF00C853),
    ),
    CosmicShopItem(
      id: 'eye_heart_pink',
      name: 'Neon Hearts',
      description: 'Adorable glowing pink heart eyes!',
      category: CosmicItemCategory.eye,
      rarity: CosmicItemRarity.rare,
      costXp: 60,
      primaryColor: Color(0xFFFF4081),
      secondaryColor: Color(0xFFF50057),
    ),
    CosmicShopItem(
      id: 'eye_cyber_visor',
      name: 'Laser Shades',
      description: 'Sleek wrap-around neon cyclops laser visor bar!',
      category: CosmicItemCategory.eye,
      rarity: CosmicItemRarity.epic,
      costXp: 85,
      primaryColor: Color(0xFF00E5FF),
      secondaryColor: Color(0xFFF43F5E),
    ),
    CosmicShopItem(
      id: 'eye_star_gold',
      name: 'Starlight Gold',
      description: 'Dazzling golden 4-point star eyes!',
      category: CosmicItemCategory.eye,
      rarity: CosmicItemRarity.legendary,
      costXp: 100,
      primaryColor: Color(0xFFFFD54F),
      secondaryColor: Color(0xFFFFAB00),
    ),

    // --- 4. STAGE BACKDROP WORLDS ---
    CosmicShopItem(
      id: 'stage_nebula',
      name: 'Starlight Dock',
      description: 'Deep purple cosmic command pedestal.',
      category: CosmicItemCategory.stage,
      rarity: CosmicItemRarity.common,
      costXp: 0,
      primaryColor: Color(0xFF651FFF),
      secondaryColor: Color(0xFF12082B),
    ),
    CosmicShopItem(
      id: 'stage_mars',
      name: 'Mars Base',
      description: 'Crimson Martian craters & twin moons horizon.',
      category: CosmicItemCategory.stage,
      rarity: CosmicItemRarity.common,
      costXp: 45,
      primaryColor: Color(0xFFEA580C),
      secondaryColor: Color(0xFF450A0A),
    ),
    CosmicShopItem(
      id: 'stage_saturn',
      name: 'Saturn Orbit',
      description: 'Icy cyan rings of Saturn & floating asteroids.',
      category: CosmicItemCategory.stage,
      rarity: CosmicItemRarity.rare,
      costXp: 65,
      primaryColor: Color(0xFF38BDF8),
      secondaryColor: Color(0xFF082F49),
    ),
    CosmicShopItem(
      id: 'stage_cyber',
      name: 'Synthwave Grid',
      description: '80s retro neon laser grid & magenta cyber sun!',
      category: CosmicItemCategory.stage,
      rarity: CosmicItemRarity.epic,
      costXp: 90,
      primaryColor: Color(0xFFF43F5E),
      secondaryColor: Color(0xFF701A75),
    ),
    CosmicShopItem(
      id: 'stage_supernova',
      name: 'Supernova Core',
      description: 'Radiant golden starlight sanctuary of legends!',
      category: CosmicItemCategory.stage,
      rarity: CosmicItemRarity.legendary,
      costXp: 125,
      primaryColor: Color(0xFFFACC15),
      secondaryColor: Color(0xFF422006),
    ),
  ];

  static CosmicShopItem? getItemById(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _syncGlobalAppearanceNotifier() {
    CurrentByteAppearanceNotifier.notifier.value = _state.appearance;
  }

  Future<void> loadForCurrentUser() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _state = const UserCosmicState();
      _lifetimeXp = 0;
      _isLoaded = true;
      _syncGlobalAppearanceNotifier();
      notifyListeners();
      return;
    }

    int fetchedXp = 0;
    bool isAdminUser =
        (user.userMetadata?['role']?.toString().toLowerCase() == 'admin');
    Map<String, dynamic>? loadedCustomization;
    String? profileAvatarStr;

    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString('cosmic_state_v2_${user.id}');
    if (localRaw != null && localRaw.isNotEmpty) {
      try {
        loadedCustomization = jsonDecode(localRaw) as Map<String, dynamic>;
      } catch (_) {}
    }

    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        if (res['role']?.toString().toLowerCase() == 'admin') {
          isAdminUser = true;
        }
        fetchedXp = (res['xp'] as num? ?? 0).toInt();
        profileAvatarStr = res['avatar_url'] as String?;
        if (res['customization'] is Map) {
          final dbMap = Map<String, dynamic>.from(res['customization'] as Map);
          if (dbMap.isNotEmpty) {
            loadedCustomization = dbMap;
          }
        }
      }
    } catch (_) {
      final meta = user.userMetadata;
      if (meta != null) {
        fetchedXp = int.tryParse(meta['xp']?.toString() ?? '0') ?? 0;
        profileAvatarStr = meta['avatar_url'] as String?;
        if (meta['cosmic_customization'] is Map) {
          loadedCustomization ??=
              Map<String, dynamic>.from(meta['cosmic_customization'] as Map);
        }
      }
    }

    if (isAdminUser) {
      // Admins have no XP or mini-game customization; keep constant Educator Byte
      _lifetimeXp = 0;
      _state = const UserCosmicState(
        equippedBody: 'body_classic',
        equippedEye: 'eye_cyan',
        equippedCostume: 'costume_educator',
        equippedStage: 'stage_nebula',
      );
      final adminUri = ByteAppearance.adminAppearance.toAvatarUrlString();
      if (profileAvatarStr != adminUri) {
        await _persistState(syncAvatarUrl: true);
      }
      _isLoaded = true;
      _syncGlobalAppearanceNotifier();
      notifyListeners();
      return;
    }

    _lifetimeXp = fetchedXp;
    _state = UserCosmicState.fromJson(loadedCustomization);

    // If profile avatar_url already has a byte:// URI and loadedCustomization was empty, sync from it
    if (loadedCustomization == null &&
        profileAvatarStr != null &&
        profileAvatarStr.startsWith('byte://')) {
      final parsed = ByteAppearance.fromAvatarUrlString(profileAvatarStr);
      _state = _state.copyWith(
        equippedBody: parsed.bodyId,
        equippedEye: parsed.eyeId,
        equippedCostume: parsed.costumeId,
        equippedStage: parsed.stageId,
      );
    }

    // Ensure the user's `profiles.avatar_url` is populated with their `byte://...` URI
    // so every screen in the app shows their Byte avatar instead of a blank or photo icon
    if (profileAvatarStr == null || !profileAvatarStr.startsWith('byte://')) {
      await _persistState(syncAvatarUrl: true);
    }

    _isLoaded = true;
    _syncGlobalAppearanceNotifier();
    notifyListeners();
  }

  Future<UserCosmicState> fetchOtherUserCosmicState(
    String userId, {
    String? fallbackAvatarUrl,
  }) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == currentUserId && _isLoaded) {
      return _state;
    }
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res != null) {
        if (res['role']?.toString().toLowerCase() == 'admin') {
          return const UserCosmicState(
            equippedBody: 'body_classic',
            equippedEye: 'eye_cyan',
            equippedCostume: 'costume_educator',
            equippedStage: 'stage_nebula',
          );
        }
        if (res['customization'] is Map) {
          final map = Map<String, dynamic>.from(res['customization'] as Map);
          if (map.isNotEmpty) {
            return UserCosmicState.fromJson(map);
          }
        }
        final av = (res['avatar_url'] as String?) ?? fallbackAvatarUrl;
        if (av != null && av.startsWith('byte://')) {
          final app = ByteAppearance.fromAvatarUrlString(av);
          return UserCosmicState(
            equippedBody: app.bodyId,
            equippedEye: app.eyeId,
            equippedCostume: app.costumeId,
            equippedStage: app.stageId,
          );
        }
      }
    } catch (_) {}

    if (fallbackAvatarUrl != null && fallbackAvatarUrl.startsWith('byte://')) {
      final app = ByteAppearance.fromAvatarUrlString(fallbackAvatarUrl);
      return UserCosmicState(
        equippedBody: app.bodyId,
        equippedEye: app.eyeId,
        equippedCostume: app.costumeId,
        equippedStage: app.stageId,
      );
    }
    return const UserCosmicState();
  }

  Future<void> _persistState({bool syncAvatarUrl = true}) async {
    _syncGlobalAppearanceNotifier();
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final jsonMap = _state.toJson();
    final avatarUri = _state.appearance.toAvatarUrlString();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cosmic_state_v2_${user.id}', jsonEncode(jsonMap));
    } catch (_) {}

    // 1. Update `profiles.avatar_url` (always exists!) so Leaderboard, Discussions,
    // Friends, and Multiplayer automatically show the user's custom Byte everywhere.
    if (syncAvatarUrl) {
      try {
        await client
            .from('profiles')
            .update({'avatar_url': avatarUri})
            .eq('id', user.id);
      } catch (_) {}
    }

    // 2. Also update `profiles.customization` if the optional JSONB column exists.
    try {
      await client
          .from('profiles')
          .update({'customization': jsonMap})
          .eq('id', user.id);
    } catch (_) {}

    // 3. Also store in auth userMetadata for instant session persistence.
    try {
      final currentMeta = user.userMetadata ?? {};
      await client.auth.updateUser(
        UserAttributes(
          data: {
            ...currentMeta,
            'avatar_url': avatarUri,
            'cosmic_customization': jsonMap,
          },
        ),
      );
    } catch (_) {}
  }

  void syncLifetimeXp(int newLifetimeXp) {
    if (newLifetimeXp != _lifetimeXp) {
      _lifetimeXp = newLifetimeXp;
      notifyListeners();
    }
  }

  bool isOwned(String itemId) => _state.ownedItems.contains(itemId);

  bool isEquipped(CosmicShopItem item) {
    switch (item.category) {
      case CosmicItemCategory.costume:
        return _state.equippedCostume == item.id;
      case CosmicItemCategory.body:
        return _state.equippedBody == item.id;
      case CosmicItemCategory.eye:
        return _state.equippedEye == item.id;
      case CosmicItemCategory.stage:
        return _state.equippedStage == item.id;
    }
  }

  Future<bool> purchaseAndEquip(CosmicShopItem item) async {
    if (isOwned(item.id)) {
      await equipItem(item);
      return true;
    }
    if (spendableXp < item.costXp) {
      return false;
    }

    final updatedOwned = List<String>.from(_state.ownedItems)..add(item.id);
    _state = _state.copyWith(
      spentXp: _state.spentXp + item.costXp,
      ownedItems: updatedOwned,
    );
    await equipItem(item, persistImmediately: false);
    await _persistState(syncAvatarUrl: true);
    notifyListeners();
    return true;
  }

  Future<void> equipItem(
    CosmicShopItem item, {
    bool persistImmediately = true,
  }) async {
    if (!isOwned(item.id)) return;

    switch (item.category) {
      case CosmicItemCategory.costume:
        _state = _state.copyWith(equippedCostume: item.id);
        break;
      case CosmicItemCategory.body:
        _state = _state.copyWith(equippedBody: item.id);
        break;
      case CosmicItemCategory.eye:
        _state = _state.copyWith(equippedEye: item.id);
        break;
      case CosmicItemCategory.stage:
        _state = _state.copyWith(equippedStage: item.id);
        break;
    }

    if (persistImmediately) {
      await _persistState(syncAvatarUrl: true);
    } else {
      _syncGlobalAppearanceNotifier();
    }
    notifyListeners();
  }

  /// Kept as a lightweight hook for study completion callers.
  Future<void> recordStudyCompletion() async {}
}
