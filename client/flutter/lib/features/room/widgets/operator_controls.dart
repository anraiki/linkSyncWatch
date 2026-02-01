import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/room_provider.dart';

class OperatorControls extends ConsumerWidget {
  const OperatorControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomNotifier = ref.read(currentRoomProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Add media button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showAddMediaDialog(context, roomNotifier),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Media'),
            ),
          ),
          const SizedBox(width: 8),

          // Skip to next
          OutlinedButton.icon(
            onPressed: () => roomNotifier.queueNext(),
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Next'),
          ),
          const SizedBox(width: 8),

          // Stop
          OutlinedButton.icon(
            onPressed: () => roomNotifier.stop(),
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMediaDialog(
      BuildContext context, RoomNotifier roomNotifier) {
    final urlController = TextEditingController();
    final filenameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Media URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/video.mp4',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: filenameController,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Filename',
                hintText: 'video.mp4',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              final filename = filenameController.text.trim();
              if (url.isEmpty || filename.isEmpty) return;
              roomNotifier.addMediaUrl(url, filename);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
