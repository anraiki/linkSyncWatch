import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/room_provider.dart';

class PlayerWidget extends ConsumerWidget {
  const PlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(playerServiceProvider);
    final playerReady = ref.watch(playerReadyProvider);
    final roomState = ref.watch(currentRoomProvider);
    final isOperator = roomState.isOperator;

    if (!playerReady) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Waiting for media...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Video(
            controller: playerService.videoController,
            controls: NoVideoControls,
          ),
        ),
        _PlayerControls(isOperator: isOperator),
      ],
    );
  }
}

class _PlayerControls extends ConsumerWidget {
  final bool isOperator;

  const _PlayerControls({required this.isOperator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(playerServiceProvider);
    final roomNotifier = ref.read(currentRoomProvider.notifier);
    final syncEnabled = ref.watch(syncEnabledProvider);

    return StreamBuilder<Duration>(
      stream: playerService.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: playerService.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black87,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12),
                      activeTrackColor:
                          Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Colors.grey[700],
                      thumbColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Slider(
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                      max: duration.inMilliseconds
                          .toDouble()
                          .clamp(1, double.infinity),
                      onChanged: isOperator
                          ? (value) {
                              roomNotifier.seek(value / 1000);
                            }
                          : null,
                    ),
                  ),

                  Row(
                    children: [
                      // Time display
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const Text(' / ',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),

                      const Spacer(),

                      // Play/Pause — everyone can control locally
                      StreamBuilder<bool>(
                        stream: playerService.playingStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            iconSize: 32,
                            onPressed: () {
                              if (isOperator) {
                                // Operator commands go through the server.
                                if (isPlaying) {
                                  roomNotifier.pause();
                                } else {
                                  roomNotifier.play(
                                    atTime:
                                        position.inMilliseconds / 1000,
                                  );
                                }
                              } else {
                                // Non-operator: local play/pause only.
                                if (isPlaying) {
                                  playerService.pause();
                                } else {
                                  playerService.play();
                                }
                              }
                            },
                          );
                        },
                      ),

                      const Spacer(),

                      // Sync toggle
                      if (!isOperator)
                        IconButton(
                          icon: Icon(
                            syncEnabled ? Icons.sync : Icons.sync_disabled,
                            color: syncEnabled ? Colors.greenAccent : Colors.grey,
                            size: 20,
                          ),
                          tooltip: syncEnabled
                              ? 'Synced to operator'
                              : 'Sync disabled',
                          onPressed: () {
                            final newValue = !syncEnabled;
                            ref.read(syncEnabledProvider.notifier).state =
                                newValue;
                            if (newValue) {
                              // Re-sync immediately.
                              roomNotifier.resync();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
