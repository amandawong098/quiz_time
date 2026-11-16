import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central Sound Effect Service for LearnByte.
/// - Style A (Soft & Subtle): General button clicks & bottom tab navigation.
/// - Style B (Playful / Arcade): Quiz option selection, correct/wrong reveal,
///   countdown ticks, live emoji reactions, and quiz completion fanfare.
class SoundService extends ChangeNotifier {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  static const String _prefKey = 'learnbyte_sfx_enabled';

  static final AudioContext _gameAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
    ),
  );

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  // Temporary per-quiz session overrides (do not overwrite system/Profile settings)
  bool _quizMusicEnabled = true;
  bool _isInQuizGameplay = false;
  bool? _quizSessionSoundOverride;

  // Mini-game background music state (reuses quiz BGM)
  bool _miniGameMusicEnabled = true;
  bool _isInMiniGame = false;

  bool get quizMusicEnabled => _quizMusicEnabled;
  bool get miniGameMusicEnabled => _miniGameMusicEnabled;
  bool get effectiveSoundEnabled => _quizSessionSoundOverride ?? _isEnabled;

  bool _initialized = false;
  bool _audioContextConfigured = false;
  DateTime _lastSpecializedSfxTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastButtonClickTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Small pool of AudioPlayers for zero-latency overlapping playback
  final List<AudioPlayer> _playerPool = [];
  int _poolIndex = 0;
  static const int _poolSize = 4;

  // Dedicated AudioPlayer for looping in-game quiz background music
  AudioPlayer? _bgmPlayer;
  StreamSubscription<void>? _bgmCompleteSub;
  String? _bgmTempFilePath;

  // Lazy-synthesized 16-bit PCM WAV buffers in memory (hot-reload safe)
  Uint8List? _softButtonClickWavCache;
  Uint8List? _softTabSwitchWavCache;
  Uint8List? _arcadeOptionSelectWavCache;
  Uint8List? _arcadeCorrectWavCache;
  Uint8List? _arcadeWrongWavCache;
  Uint8List? _arcadeEmojiPopWavCache;
  Uint8List? _arcadeQuizCompleteWavCache;
  Uint8List? _arcadeTimerTickWavCache;
  Uint8List? _mascotChirpWavCache;
  Uint8List? _arcadeQuizBgmWavCache;

  Uint8List get _softButtonClickWav =>
      _softButtonClickWavCache ??= _generateSoftButtonClick();
  Uint8List get _softTabSwitchWav =>
      _softTabSwitchWavCache ??= _generateSoftTabSwitch();
  Uint8List get _arcadeOptionSelectWav =>
      _arcadeOptionSelectWavCache ??= _generateArcadeOptionSelect();
  Uint8List get _arcadeCorrectWav =>
      _arcadeCorrectWavCache ??= _generateArcadeCorrect();
  Uint8List get _arcadeWrongWav =>
      _arcadeWrongWavCache ??= _generateArcadeWrong();
  Uint8List get _arcadeEmojiPopWav =>
      _arcadeEmojiPopWavCache ??= _generateArcadeEmojiPop();
  Uint8List get _arcadeQuizCompleteWav =>
      _arcadeQuizCompleteWavCache ??= _generateArcadeQuizComplete();
  Uint8List get _arcadeTimerTickWav =>
      _arcadeTimerTickWavCache ??= _generateArcadeTimerTick();
  Uint8List get _mascotChirpWav =>
      _mascotChirpWavCache ??= _generateMascotChirp();
  Uint8List get _arcadeQuizBgmWav =>
      _arcadeQuizBgmWavCache ??= _generateArcadeQuizBgmLoop();

  Future<void> init() async {
    if (_initialized) {
      await _ensureAudioSetup();
      return;
    }
    _initialized = true;

    // Pre-warm all sound buffers in memory
    _softButtonClickWav;
    _softTabSwitchWav;
    _arcadeOptionSelectWav;
    _arcadeCorrectWav;
    _arcadeWrongWav;
    _arcadeEmojiPopWav;
    _arcadeQuizCompleteWav;
    _arcadeTimerTickWav;
    _mascotChirpWav;
    _arcadeQuizBgmWav;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}

    await _ensureAudioSetup();
    notifyListeners();
  }

  Future<void> _ensureAudioSetup() async {
    try {
      if (!_audioContextConfigured) {
        _audioContextConfigured = true;
        await AudioPlayer.global.setAudioContext(_gameAudioContext);
        for (final p in _playerPool) {
          await p.setAudioContext(_gameAudioContext);
        }
      }
      if (_playerPool.isEmpty) {
        for (int i = 0; i < _poolSize; i++) {
          final player = AudioPlayer();
          await player.setAudioContext(_gameAudioContext);
          await player.setReleaseMode(ReleaseMode.stop);
          _playerPool.add(player);
        }
      }
      if (_bgmPlayer == null) {
        final bgm = AudioPlayer();
        await bgm.setAudioContext(_gameAudioContext);
        await bgm.setReleaseMode(ReleaseMode.loop);
        _bgmCompleteSub?.cancel();
        _bgmCompleteSub = bgm.onPlayerComplete.listen((_) {
          if (_isInQuizGameplay && _quizMusicEnabled) {
            _startBgmPlayback();
          } else if (_isInMiniGame && _miniGameMusicEnabled) {
            _startMiniGameBgmPlayback();
          }
        });
        _bgmPlayer = bgm;
      }
    } catch (e) {
      debugPrint('SoundService AudioPlayer init error: $e');
    }
  }

  Future<void> toggleSound() async {
    await setEnabled(!_isEnabled);
  }

  Future<void> setEnabled(bool value) async {
    if (_isEnabled == value) return;
    _isEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isEnabled);
    } catch (_) {}
    if (_isEnabled) {
      if (!_initialized) init();
      _playBytes(_softTabSwitchWav, volume: 0.50);
    }
  }

  /// Sets temporary music/sound overrides for the current quiz session only,
  /// without modifying the user's global system settings in SharedPreferences.
  void setQuizSessionOverride({
    bool? musicEnabled,
    bool? soundEnabled,
    bool playFeedback = true,
  }) {
    bool changed = false;
    if (musicEnabled != null && _quizMusicEnabled != musicEnabled) {
      _quizMusicEnabled = musicEnabled;
      changed = true;
      if (_isInQuizGameplay) {
        if (_quizMusicEnabled) {
          _startBgmPlayback();
        } else {
          _pauseBgmPlayback();
        }
      }
    }
    if (soundEnabled != null && _quizSessionSoundOverride != soundEnabled) {
      _quizSessionSoundOverride = soundEnabled;
      changed = true;
      if (soundEnabled && playFeedback) {
        if (!_initialized) init();
        _playBytes(_softTabSwitchWav, volume: 0.50);
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Starts in-game background music for quiz gameplay if Music is enabled for the session.
  Future<void> startQuizMusic() async {
    _isInQuizGameplay = true;
    await _ensureAudioSetup();
    if (_quizMusicEnabled) {
      await _startBgmPlayback();
    }
  }

  /// Stops in-game background music when leaving quiz gameplay.
  Future<void> stopQuizMusic() async {
    _isInQuizGameplay = false;
    try {
      await _bgmPlayer?.stop();
    } catch (_) {}
  }

  /// Starts chill cosmic lounge music for the Byte Avatar Studio mini-game.
  Future<void> startMiniGameMusic() async {
    _isInMiniGame = true;
    _isInQuizGameplay = false;
    await _ensureAudioSetup();
    if (_miniGameMusicEnabled) {
      await _startMiniGameBgmPlayback();
    }
  }

  /// Stops mini-game background music when leaving the Byte Avatar Studio.
  Future<void> stopMiniGameMusic() async {
    _isInMiniGame = false;
    try {
      await _bgmPlayer?.stop();
    } catch (_) {}
  }

  Future<void> toggleMiniGameMusic() async {
    _miniGameMusicEnabled = !_miniGameMusicEnabled;
    notifyListeners();
    if (!_isInMiniGame) return;
    if (_miniGameMusicEnabled) {
      await _startMiniGameBgmPlayback();
    } else {
      await _pauseBgmPlayback();
    }
  }

  Future<void> _startMiniGameBgmPlayback() async {
    try {
      await _ensureAudioSetup();
      if (_bgmPlayer == null || !_isInMiniGame || !_miniGameMusicEnabled) {
        return;
      }
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(0.28);

      final filePath = await _ensureBgmFile();
      if (filePath != null) {
        await _bgmPlayer!.play(DeviceFileSource(filePath));
      } else {
        await _bgmPlayer!.play(
          BytesSource(_arcadeQuizBgmWav, mimeType: 'audio/wav'),
        );
      }
    } catch (e) {
      debugPrint('Error starting mini-game BGM: $e');
    }
  }

  Future<String?> _ensureBgmFile() async {
    if (kIsWeb) return null;
    if (_bgmTempFilePath != null) {
      try {
        if (await File(_bgmTempFilePath!).exists()) {
          return _bgmTempFilePath;
        }
      } catch (_) {}
    }
    try {
      final tempFile =
          File('${Directory.systemTemp.path}/learnbyte_quiz_bgm_v1.wav');
      await tempFile.writeAsBytes(_arcadeQuizBgmWav, flush: true);
      _bgmTempFilePath = tempFile.path;
      return _bgmTempFilePath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startBgmPlayback() async {
    try {
      await _ensureAudioSetup();
      if (_bgmPlayer == null || !_isInQuizGameplay || !_quizMusicEnabled) return;
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(0.32);

      final filePath = await _ensureBgmFile();
      if (filePath != null) {
        await _bgmPlayer!.play(DeviceFileSource(filePath));
      } else {
        await _bgmPlayer!.play(
          BytesSource(_arcadeQuizBgmWav, mimeType: 'audio/wav'),
        );
      }
    } catch (e) {
      debugPrint('Error starting quiz BGM: $e');
    }
  }

  Future<void> _pauseBgmPlayback() async {
    try {
      await _bgmPlayer?.pause();
    } catch (_) {}
  }

  /// Clears any temporary quiz session overrides and stops quiz music so global system settings resume.
  /// Defers notifyListeners() to a post-frame callback so calling this inside Widget.dispose()
  /// never triggers a "widget tree was locked" assertion error.
  void clearQuizSessionOverride() {
    unawaited(stopQuizMusic());
    if (!_quizMusicEnabled || _quizSessionSoundOverride != null) {
      _quizMusicEnabled = true;
      _quizSessionSoundOverride = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Style A: Soft & Subtle (General UI)
  // ---------------------------------------------------------------------------

  /// Soft, modern UI pop for general button taps.
  void playButtonClick() {
    if (!effectiveSoundEnabled) return;

    final now = DateTime.now();
    // Skip if a specialized sound or another click just played
    if (now.difference(_lastSpecializedSfxTime).inMilliseconds < 140) return;
    if (now.difference(_lastButtonClickTime).inMilliseconds < 70) return;
    _lastButtonClickTime = now;

    if (!_initialized) init();
    _playBytes(_softButtonClickWav, volume: 0.42);
  }

  /// Smooth, airy cosmic micro-chime when switching bottom navigation tabs.
  void playTabSwitch() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_softTabSwitchWav, volume: 0.50);
  }

  // ---------------------------------------------------------------------------
  // Style B: Playful / Arcade (Quiz & Multiplayer)
  // ---------------------------------------------------------------------------

  /// Crisp arcade blip when selecting a quiz option.
  void playOptionSelect() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_arcadeOptionSelectWav, volume: 0.65);
  }

  /// Upbeat arcade 3-note ascending chime for a correct answer.
  void playCorrectAnswer() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_arcadeCorrectWav, volume: 0.78);
  }

  /// Playful arcade descending two-tone buzz for a wrong answer or timeout.
  void playWrongAnswer() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_arcadeWrongWav, volume: 0.68);
  }

  /// Bubbly arcade pop when sending a live emoji reaction.
  void playEmojiReaction() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_arcadeEmojiPopWav, volume: 0.60);
  }

  /// Celebratory arcade victory fanfare when finishing a quiz.
  void playQuizComplete() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_arcadeQuizCompleteWav, volume: 0.82);
  }

  /// Subtle arcade countdown tick for the final 5 seconds of a question.
  void playTimerTick() {
    if (!effectiveSoundEnabled) return;

    if (!_initialized) init();
    _playBytes(_arcadeTimerTickWav, volume: 0.45);
  }

  /// Cute melodic astro-bot chirp when tapping Byte the mascot.
  void playMascotChirp() {
    if (!effectiveSoundEnabled) return;

    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    _playBytes(_mascotChirpWav, volume: 0.65);
  }

  void _playBytes(Uint8List wavBytes, {double volume = 0.6}) {
    unawaited(() async {
      try {
        await _ensureAudioSetup();
        if (_playerPool.isEmpty) return;
        final player = _playerPool[_poolIndex];
        _poolIndex = (_poolIndex + 1) % _playerPool.length;
        await player.stop();
        await player.setVolume(volume);
        await player.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      } catch (_) {}
    }());
  }

  // ---------------------------------------------------------------------------
  // In-Memory 16-bit PCM WAV Synthesizer (22,050 Hz Mono)
  // ---------------------------------------------------------------------------
  static const int _sampleRate = 22050;

  /// Style A: Gentle cosine-enveloped warm UI tap (42ms, 620Hz -> 360Hz).
  static Uint8List _generateSoftButtonClick() {
    const durationSec = 0.042;
    final numSamples = (_sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    double phase = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      // Exponential frequency drop for a natural soft wood/glass tap feel
      final freq = 360.0 + 260.0 * exp(-t * 6.0);
      phase += (2 * pi * freq) / _sampleRate;
      // Fast attack, smooth cosine decay
      final env = sin(pi * pow(1.0 - t, 1.8));
      samples[i] = sin(phase) * env * 0.65;
    }
    return _encodeWav(samples);
  }

  /// Style A: Smooth two-note airy cosmic chime for tab switching (95ms).
  static Uint8List _generateSoftTabSwitch() {
    const durationSec = 0.095;
    final numSamples = (_sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    double phase1 = 0.0;
    double phase2 = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      // Smooth glide from C5 (523Hz) to E5 (659Hz)
      final freq = t < 0.45 ? 523.25 : 659.25;
      phase1 += (2 * pi * freq) / _sampleRate;
      phase2 += (2 * pi * freq * 1.5) / _sampleRate;

      final attack = (i / (_sampleRate * 0.008)).clamp(0.0, 1.0);
      final decay = pow(1.0 - t, 1.4).toDouble();
      final env = attack * decay;

      samples[i] = (0.75 * sin(phase1) + 0.25 * sin(phase2)) * env * 0.65;
    }
    return _encodeWav(samples);
  }

  /// Style B: Crisp arcade blip for selecting a quiz option (75ms).
  static Uint8List _generateArcadeOptionSelect() {
    const durationSec = 0.075;
    final numSamples = (_sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    double phase = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      // Upward arcade pitch jump: D5 (587Hz) -> A5 (880Hz)
      final freq = t < 0.4 ? 587.33 : 880.0;
      phase += (2 * pi * freq) / _sampleRate;
      final env = pow(1.0 - t, 1.1).toDouble();
      // Blend sine + triangle-like third harmonic for arcade character
      final wave = 0.75 * sin(phase) + 0.25 * sin(phase * 3);
      samples[i] = wave * env * 0.75;
    }
    return _encodeWav(samples);
  }

  /// Style B: Playful arcade ascending arpeggio (C5 -> E5 -> G5 -> C6, 340ms).
  static Uint8List _generateArcadeCorrect() {
    const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    const noteDurations = [0.065, 0.065, 0.065, 0.155];
    final totalSec = noteDurations.reduce((a, b) => a + b);
    final numSamples = (_sampleRate * totalSec).round();
    final samples = Float64List(numSamples);

    double phase = 0.0;
    int sampleIndex = 0;

    for (int n = 0; n < notes.length; n++) {
      final freq = notes[n];
      final count = (_sampleRate * noteDurations[n]).round();
      for (int i = 0; i < count && sampleIndex < numSamples; i++) {
        final localT = i / count;
        phase += (2 * pi * freq) / _sampleRate;
        final attack = (i / (_sampleRate * 0.004)).clamp(0.0, 1.0);
        final decay = n == notes.length - 1
            ? pow(1.0 - localT, 1.5).toDouble()
            : pow(1.0 - localT * 0.5, 1.2).toDouble();
        final wave =
            0.70 * sin(phase) + 0.20 * sin(phase * 2) + 0.10 * sin(phase * 3);
        samples[sampleIndex++] = wave * attack * decay * 0.80;
      }
    }
    return _encodeWav(samples);
  }

  /// Style B: Playful arcade descending two-tone buzz (Eb4 -> A3, 290ms).
  static Uint8List _generateArcadeWrong() {
    const notes = [311.13, 220.00]; // Eb4 -> A3
    const noteDurations = [0.11, 0.18];
    final totalSec = noteDurations.reduce((a, b) => a + b);
    final numSamples = (_sampleRate * totalSec).round();
    final samples = Float64List(numSamples);

    double phase = 0.0;
    int sampleIndex = 0;

    for (int n = 0; n < notes.length; n++) {
      final freq = notes[n];
      final count = (_sampleRate * noteDurations[n]).round();
      for (int i = 0; i < count && sampleIndex < numSamples; i++) {
        final localT = i / count;
        phase += (2 * pi * freq) / _sampleRate;
        final attack = (i / (_sampleRate * 0.005)).clamp(0.0, 1.0);
        final decay = pow(1.0 - localT, 1.2).toDouble();
        // Richer odd/even harmonics for an arcade buzzer texture
        final wave = 0.60 * sin(phase) +
            0.25 * sin(phase * 2) +
            0.15 * sin(phase * 3);
        samples[sampleIndex++] = wave * attack * decay * 0.75;
      }
    }
    return _encodeWav(samples);
  }

  /// Style B: Cute bubbly arcade pop for live emoji reactions (85ms).
  static Uint8List _generateArcadeEmojiPop() {
    const durationSec = 0.085;
    final numSamples = (_sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    double phase = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      // Fast upward pitch sweep (420Hz -> 1080Hz)
      final freq = 420.0 + 660.0 * pow(t, 1.5);
      phase += (2 * pi * freq) / _sampleRate;
      final env = sin(pi * t);
      samples[i] = sin(phase) * env * 0.75;
    }
    return _encodeWav(samples);
  }

  /// Style B: Celebratory arcade fanfare for completing a quiz (480ms).
  static Uint8List _generateArcadeQuizComplete() {
    const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    const noteDurations = [0.08, 0.08, 0.08, 0.24];
    final totalSec = noteDurations.reduce((a, b) => a + b);
    final numSamples = (_sampleRate * totalSec).round();
    final samples = Float64List(numSamples);

    double phase1 = 0.0;
    double phase2 = 0.0;
    int sampleIndex = 0;

    for (int n = 0; n < notes.length; n++) {
      final freq = notes[n];
      final count = (_sampleRate * noteDurations[n]).round();
      for (int i = 0; i < count && sampleIndex < numSamples; i++) {
        final localT = i / count;
        phase1 += (2 * pi * freq) / _sampleRate;
        phase2 += (2 * pi * (freq * 1.25)) / _sampleRate; // Major third shimmer
        final attack = (i / (_sampleRate * 0.005)).clamp(0.0, 1.0);
        final decay = n == notes.length - 1
            ? pow(1.0 - localT, 1.3).toDouble()
            : pow(1.0 - localT * 0.35, 1.1).toDouble();
        final wave = n == notes.length - 1
            ? (0.65 * sin(phase1) + 0.20 * sin(phase2) + 0.15 * sin(phase1 * 2))
            : (0.75 * sin(phase1) + 0.25 * sin(phase1 * 2));
        samples[sampleIndex++] = wave * attack * decay * 0.82;
      }
    }
    return _encodeWav(samples);
  }

  /// Style B: Crisp arcade countdown tick (38ms, 920Hz).
  static Uint8List _generateArcadeTimerTick() {
    const durationSec = 0.038;
    final numSamples = (_sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    double phase = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      phase += (2 * pi * 920.0) / _sampleRate;
      final env = pow(1.0 - t, 2.2).toDouble();
      samples[i] = sin(phase) * env * 0.65;
    }
    return _encodeWav(samples);
  }

  /// Cute melodic two-note astro-bot whistle/chirp for Byte the mascot (155ms).
  static Uint8List _generateMascotChirp() {
    const durationSec = 0.155;
    final numSamples = (_sampleRate * durationSec).round();
    final samples = Float64List(numSamples);
    double phase = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      double freq;
      double env;
      if (t < 0.42) {
        final localT = t / 0.42;
        // First little chirp: 680Hz -> 1020Hz
        freq = 680.0 + 340.0 * sin(pi * 0.5 * localT);
        env = sin(pi * localT);
      } else if (t < 0.50) {
        freq = 800.0;
        env = 0.0; // Tiny gap between chirps
      } else {
        final localT = (t - 0.50) / 0.50;
        // Second cheerful upward whistle: 880Hz -> 1420Hz
        freq = 880.0 + 540.0 * pow(localT, 1.3);
        env = sin(pi * pow(localT, 0.75));
      }
      phase += (2 * pi * freq) / _sampleRate;
      samples[i] = (0.8 * sin(phase) + 0.2 * sin(phase * 2)) * env * 0.72;
    }
    return _encodeWav(samples);
  }

  /// Upbeat Kahoot / Space-Arcade thinking music loop (4 bars at 120 BPM = 8.0s).
  /// Combines a bouncy syncopated pluck melody, warm cosmic synth chords,
  /// octave bass groove, and soft four-on-the-floor pulse beat.
  static Uint8List _generateArcadeQuizBgmLoop() {
    const double durationSec = 8.0; // 16 beats at 120 BPM (64 sixteenth-note steps)
    final int numSamples = (_sampleRate * durationSec).round(); // 176,400 samples
    final Float64List samples = Float64List(numSamples);

    // 64-step (4-bar) Kahoot-style bouncy pluck melody in A minor / C major (0.0 = rest)
    // Bar 1: Am7 | Bar 2: Fmaj7 | Bar 3: Cmaj7 | Bar 4: G6 -> E7 turnaround
    const List<double> melodyFreqs = [
      // Bar 1 (Am7: A4=440, C5=523.25, E5=659.25, G5=783.99, A5=880)
      440.00, 0.0, 523.25, 659.25, 0.0, 523.25, 783.99, 0.0,
      659.25, 523.25, 440.00, 0.0, 523.25, 0.0, 659.25, 0.0,
      // Bar 2 (Fmaj7: F4=349.23, A4=440, C5=523.25, E5=659.25, G5=783.99)
      349.23, 0.0, 440.00, 523.25, 0.0, 440.00, 659.25, 0.0,
      523.25, 440.00, 349.23, 0.0, 440.00, 523.25, 659.25, 0.0,
      // Bar 3 (Cmaj7: G4=392.00, C5=523.25, E5=659.25, G5=783.99, A5=880)
      523.25, 0.0, 659.25, 783.99, 0.0, 659.25, 880.00, 0.0,
      783.99, 659.25, 523.25, 0.0, 659.25, 0.0, 783.99, 0.0,
      // Bar 4 (G6 -> E7 turnaround: G4=392, B4=493.88, D5=587.33, E5=659.25, G#4=415.30)
      587.33, 0.0, 493.88, 392.00, 0.0, 493.88, 587.33, 0.0,
      659.25, 0.0, 587.33, 493.88, 523.25, 0.0, 493.88, 0.0,
    ];

    // Bass root notes per bar (Am -> F -> C -> G/E)
    const List<double> barBassRoots = [
      110.00, // A2
      87.31,  // F2
      130.81, // C3
      98.00,  // G2
    ];

    // Warm cosmic synth pad triads per bar
    const List<List<double>> barPadChords = [
      [220.00, 261.63, 329.63], // Am (A3, C4, E4)
      [174.61, 220.00, 261.63], // F  (F3, A3, C4)
      [261.63, 329.63, 392.00], // C  (C4, E4, G4)
      [196.00, 246.94, 293.66], // G  (G3, B3, D4)
    ];

    const double stepSec = 0.125; // 16th note at 120 BPM
    final double samplesPerStep = _sampleRate * stepSec;

    double leadPhase = 0.0;
    double bassPhase = 0.0;
    int lastStep = -1;

    for (int i = 0; i < numSamples; i++) {
      final double timeSec = i / _sampleRate;
      final int step = (i / samplesPerStep).floor().clamp(0, 63);
      final double stepLocalT = (i - step * samplesPerStep) / samplesPerStep;
      final int bar = (step ~/ 16).clamp(0, 3);
      final int stepInBeat = step % 4;

      if (step != lastStep) {
        lastStep = step;
      }

      // 1. Lead Cosmic Pluck Melody
      double leadSample = 0.0;
      final double leadFreq = melodyFreqs[step];
      if (leadFreq > 0.0) {
        leadPhase += (2 * pi * leadFreq) / _sampleRate;
        final double attack = (stepLocalT / 0.06).clamp(0.0, 1.0);
        final double decay = exp(-stepLocalT * 4.2);
        final double pluckWave = 0.70 * sin(leadPhase) +
            0.22 * sin(leadPhase * 2.0) +
            0.08 * sin(leadPhase * 3.0);
        leadSample = pluckWave * attack * decay * 0.36;
      }

      // 2. Bouncy Octave Arcade Bassline (plays on 8th-note steps: 0, 2, 4, 6...)
      double bassSample = 0.0;
      double bassRoot = barBassRoots[bar];
      if (bar == 3 && step >= 56) {
        bassRoot = 82.41; // E2 turnaround on final 2 beats
      }
      // Octave jump on the "&" eighth note (stepInBeat == 2)
      final double bassFreq = (stepInBeat >= 2) ? bassRoot * 2.0 : bassRoot;
      final double eighthLocalT = ((step % 2) + stepLocalT) * 0.5;
      bassPhase += (2 * pi * bassFreq) / _sampleRate;
      final double bassAttack = (eighthLocalT / 0.04).clamp(0.0, 1.0);
      final double bassDecay = exp(-eighthLocalT * 3.4);
      final double bassWave =
          0.75 * sin(bassPhase) + 0.25 * sin(bassPhase * 2.0);
      bassSample = bassWave * bassAttack * bassDecay * 0.32;

      // 3. Warm Cosmic Synth Pad Chords
      final List<double> chord = barPadChords[bar];
      final double padLfo = 0.85 + 0.15 * sin(2 * pi * 1.5 * timeSec);
      final double padWave = (sin(2 * pi * chord[0] * timeSec) +
              sin(2 * pi * chord[1] * timeSec) +
              sin(2 * pi * chord[2] * timeSec)) /
          3.0;
      final double padSample = padWave * padLfo * 0.16;

      // 4. Soft Arcade Four-on-the-Floor Kick + Off-beat Hi-Hat Pulse
      double drumSample = 0.0;
      if (stepInBeat == 0) {
        // Soft kick on every quarter beat
        final double kickEnv = exp(-stepLocalT * 9.5);
        final double kickFreq = 58.0 + 95.0 * exp(-stepLocalT * 18.0);
        drumSample += sin(2 * pi * kickFreq * (stepLocalT * stepSec)) *
            kickEnv *
            0.26;
      } else if (stepInBeat == 2) {
        // Subtle metallic hi-hat tick on the off-beat
        final double hatEnv = exp(-stepLocalT * 22.0);
        final double pseudoNoise =
            sin(i * 1.73) * cos(i * 2.91) * sin(i * 4.17);
        drumSample += pseudoNoise * hatEnv * 0.08;
      }

      // Mix all 4 layers together with soft headroom
      double mixed = leadSample + bassSample + padSample + drumSample;

      // Smooth 6ms micro fade-in/out at loop boundaries to prevent any click
      const int fadeSamples = 132;
      if (i < fadeSamples) {
        mixed *= i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        mixed *= (numSamples - i) / fadeSamples;
      }

      samples[i] = mixed.clamp(-0.95, 0.95);
    }

    return _encodeWav(samples);
  }

  /// Encodes normalized [-1.0, 1.0] samples into a standard 44-byte header WAV.
  static Uint8List _encodeWav(Float64List samples) {
    final int numSamples = samples.length;
    final int dataSize = numSamples * 2; // 16-bit mono = 2 bytes per sample
    final int fileSize = 36 + dataSize;

    final ByteData buffer = ByteData(44 + dataSize);

    // "RIFF" chunk descriptor
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // "fmt " sub-chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels (1 = mono)
    buffer.setUint32(24, _sampleRate, Endian.little); // SampleRate
    buffer.setUint32(28, _sampleRate * 2, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample

    // "data" sub-chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final double clamped = samples[i].clamp(-1.0, 1.0);
      final int pcm16 = (clamped * 32767.0).round();
      buffer.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}

/// Global wrapper that detects taps on interactive UI elements (buttons, cards,
/// icons, pills, etc.) and plays the soft Style A click sound if no specialized
/// sound effect was already triggered by that tap.
class GlobalSoundTapDetector extends StatefulWidget {
  final Widget child;

  const GlobalSoundTapDetector({super.key, required this.child});

  @override
  State<GlobalSoundTapDetector> createState() => _GlobalSoundTapDetectorState();
}

class _GlobalSoundTapDetectorState extends State<GlobalSoundTapDetector> {
  Offset? _downPosition;
  DateTime? _downTime;

  bool _isInteractiveHit(Offset globalPosition) {
    try {
      final HitTestResult result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(
        result,
        globalPosition,
        WidgetsBinding.instance.platformDispatcher.implicitView?.viewId ?? 0,
      );

      for (final entry in result.path) {
        final target = entry.target;
        final runtimeTypeStr = target.runtimeType.toString();
        // Match Material buttons, InkWells, IconButtons, GestureDetectors, Switches, Checkboxes, Radios
        if (runtimeTypeStr.contains('RenderInkFeatures') ||
            runtimeTypeStr.contains('_RenderInkFeatures') ||
            target is RenderPointerListener ||
            (target is RenderSemanticsAnnotations &&
                (target.properties.button == true ||
                    target.properties.toggled != null ||
                    target.properties.checked != null))) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _downPosition = event.position;
        _downTime = DateTime.now();
      },
      onPointerUp: (event) {
        final downPos = _downPosition;
        final downTime = _downTime;
        _downPosition = null;
        _downTime = null;

        if (downPos == null || downTime == null) return;

        // Ignore drags/scrolls and long presses
        final distance = (event.position - downPos).distance;
        final elapsedMs = DateTime.now().difference(downTime).inMilliseconds;
        if (distance > 14.0 || elapsedMs > 500) return;

        final tappedInteractive = _isInteractiveHit(event.position);
        if (!tappedInteractive) return;

        // Wait briefly so specialized handlers (tab switch, quiz answer, etc.)
        // run first and suppress the generic button click.
        Future.delayed(const Duration(milliseconds: 18), () {
          SoundService.instance.playButtonClick();
        });
      },
      child: widget.child,
    );
  }
}
