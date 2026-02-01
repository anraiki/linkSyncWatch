import 'package:flutter/material.dart';
import '../../../models/room.dart';

class RoomCard extends StatelessWidget {
  final RoomSummary room;
  final VoidCallback onJoin;

  const RoomCard({
    super.key,
    required this.room,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Room info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (room.currentMediaFilename != null)
                    Text(
                      'Now playing: ${room.currentMediaFilename}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(status: room.status),
                      const SizedBox(width: 8),
                      if (room.currentTime != null &&
                          room.status == 'playing')
                        Text(
                          _formatSeconds(room.currentTime!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // User count
            Column(
              children: [
                Text(
                  '${room.userCount}/${room.capacity}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const Text('users', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onJoin,
                  child: const Text('Join'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(double seconds) {
    final dur = Duration(seconds: seconds.toInt());
    final h = dur.inHours;
    final m = dur.inMinutes.remainder(60);
    final s = dur.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'playing' => (Colors.green, 'Playing'),
      'paused' => (Colors.orange, 'Paused'),
      'waiting' => (Colors.blue, 'Waiting'),
      _ => (Colors.grey, 'Idle'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
