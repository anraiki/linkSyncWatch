import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/room_provider.dart';

class QueueListWidget extends ConsumerWidget {
  const QueueListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(currentRoomProvider);
    final room = roomState.room;
    if (room == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Now playing
          if (room.currentMedia != null) ...[
            const Text(
              'NOW PLAYING',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_filled),
                title: Text(
                  room.currentMedia!.filename,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: room.currentMedia!.size > 0
                    ? Text(_formatBytes(room.currentMedia!.size))
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Queue
          const Text(
            'QUEUE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: room.queue.isEmpty
                ? const Center(
                    child: Text(
                      'Queue is empty',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: room.queue.length,
                    itemBuilder: (context, index) {
                      final media = room.queue[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(
                            media.filename,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: roomState.isOperator
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      size: 20),
                                  onPressed: () {
                                    ref
                                        .read(currentRoomProvider.notifier)
                                        .removeMedia(media.id);
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
