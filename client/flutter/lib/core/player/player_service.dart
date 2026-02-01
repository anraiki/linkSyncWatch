import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerService {
  late final Player player;
  late final VideoController videoController;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get playingStream => player.stream.playing;
  Stream<bool> get completedStream => player.stream.completed;

  Duration get position => player.state.position;
  Duration get duration => player.state.duration;
  bool get isPlaying => player.state.playing;

  Future<void> initialize() async {
    if (_isInitialized) return;

    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024,
      ),
    );

    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _isInitialized = true;
  }

  Future<void> loadFile(String path, {bool autoPlay = false}) async {
    await player.open(Media(path), play: autoPlay);
    await _waitForVideoReady();
  }

  Future<void> loadUrl(String url, {bool autoPlay = false}) async {
    await player.open(Media(url), play: autoPlay);
    await _waitForVideoReady();
  }

  Future<void> _waitForVideoReady() async {
    // Wait for the video output surface to render the first frame.
    // This is critical on Windows where the Video widget must be attached.
    await videoController.waitUntilFirstFrameRendered
        .timeout(const Duration(seconds: 5), onTimeout: () {});

    // Also wait until duration is known, meaning the file is actually loaded.
    if (player.state.duration == Duration.zero) {
      await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5), onTimeout: () => Duration.zero);
    }
  }

  Future<void> play() async {
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await player.setVolume(volume * 100);
  }

  Future<void> stop() async {
    await player.stop();
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await player.dispose();
    }
    _isInitialized = false;
  }
}
