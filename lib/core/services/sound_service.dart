import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central Sound Effect Service for LearnByte.
/// - Style A (Soft & Subtle): General button clicks & bottom tab navigation.
/// - Style B (Playful / Arcade): Quiz option selection, correct/wrong reveal,
///   countdown ticks, live emoji reactions, and quiz completion fanfare.
class SoundService extends ChangeNotifier {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  static const String _prefKey = 'learnbyte_sfx_enabled';

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  bool _initialized = false;
  DateTime _lastSpecializedSfxTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastButtonClickTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Small pool of AudioPlayers for zero-latency overlapping playback
  final List<AudioPlayer> _playerPool = [];
  int _poolIndex = 0;
  static const int _poolSize = 4;

  // Pre-synthesized 16-bit PCM WAV buffers in memory
  late final Uint8List _softButtonClickWav;
  late final Uint8List _softTabSwitchWav;
  late final Uint8List _arcadeOptionSelectWav;
  late final Uint8List _arcadeCorrectWav;
  late final Uint8List _arcadeWrongWav;
  late final Uint8List _arcadeEmojiPopWav;
  late final Uint8List _arcadeQuizCompleteWav;
  late final Uint8List _arcadeTimerTickWav;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Synthesize all sound buffers in memory
    _softButtonClickWav = _generateSoftButtonClick();
    _softTabSwitchWav = _generateSoftTabSwitch();
    _arcadeOptionSelectWav = _generateArcadeOptionSelect();
    _arcadeCorrectWav = _generateArcadeCorrect();
    _arcadeWrongWav = _generateArcadeWrong();
    _arcadeEmojiPopWav = _generateArcadeEmojiPop();
    _arcadeQuizCompleteWav = _generateArcadeQuizComplete();
    _arcadeTimerTickWav = _generateArcadeTimerTick();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}

    try {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        _playerPool.add(player);
      }
    } catch (e) {
      debugPrint('SoundService AudioPlayer init error: $e');
    }

    notifyListeners();
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
      playTabSwitch();
    }
  }

  // ---------------------------------------------------------------------------
  // Style A: Soft & Subtle (General UI)
  // ---------------------------------------------------------------------------

  /// Soft, modern UI pop for general button taps.
  void playButtonClick() {
    if (!_isEnabled) return;
    final now = DateTime.now();
    // Skip if a specialized sound or another click just played
    if (now.difference(_lastSpecializedSfxTime).inMilliseconds < 140) return;
    if (now.difference(_lastButtonClickTime).inMilliseconds < 70) return;
    _lastButtonClickTime = now;

    if (!_initialized) init();
    HapticFeedback.selectionClick();
    _playBytes(_softButtonClickWav, volume: 0.42);
  }

  /// Smooth, airy cosmic micro-chime when switching bottom navigation tabs.
  void playTabSwitch() {
    if (!_isEnabled) return;
    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    HapticFeedback.lightImpact();
    _playBytes(_softTabSwitchWav, volume: 0.50);
  }

  // ---------------------------------------------------------------------------
  // Style B: Playful / Arcade (Quiz & Multiplayer)
  // ---------------------------------------------------------------------------

  /// Crisp arcade blip when selecting a quiz option.
  void playOptionSelect() {
    if (!_isEnabled) return;
    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    HapticFeedback.selectionClick();
    _playBytes(_arcadeOptionSelectWav, volume: 0.65);
  }

  /// Upbeat arcade 3-note ascending chime for a correct answer.
  void playCorrectAnswer() {
    if (!_isEnabled) return;
    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    HapticFeedback.mediumImpact();
    _playBytes(_arcadeCorrectWav, volume: 0.78);
  }

  /// Playful arcade descending two-tone buzz for a wrong answer or timeout.
  void playWrongAnswer() {
    if (!_isEnabled) return;
    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    HapticFeedback.heavyImpact();
    _playBytes(_arcadeWrongWav, volume: 0.68);
  }

  /// Bubbly arcade pop when sending a live emoji reaction.
  void playEmojiReaction() {
    if (!_isEnabled) return;
    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    HapticFeedback.lightImpact();
    _playBytes(_arcadeEmojiPopWav, volume: 0.60);
  }

  /// Celebratory arcade victory fanfare when finishing a quiz.
  void playQuizComplete() {
    if (!_isEnabled) return;
    _lastSpecializedSfxTime = DateTime.now();
    if (!_initialized) init();
    HapticFeedback.mediumImpact();
    _playBytes(_arcadeQuizCompleteWav, volume: 0.82);
  }

  /// Subtle arcade countdown tick for the final 5 seconds of a question.
  void playTimerTick() {
    if (!_isEnabled) return;
    if (!_initialized) init();
    _playBytes(_arcadeTimerTickWav, volume: 0.45);
  }

  void _playBytes(Uint8List wavBytes, {double volume = 0.6}) {
    if (_playerPool.isEmpty) return;
    final player = _playerPool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _playerPool.length;

    unawaited(() async {
      try {
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
