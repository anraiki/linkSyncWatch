import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/player/player_service.dart';

final playerServiceProvider = Provider<PlayerService>((ref) {
  final player = PlayerService();
  ref.onDispose(() => player.dispose());
  return player;
});

/// Reactive flag that the UI watches to know when a file is loaded in the player.
final playerReadyProvider = StateProvider<bool>((ref) => false);

/// Whether the local player syncs to the operator's playback commands.
final syncEnabledProvider = StateProvider<bool>((ref) => true);
