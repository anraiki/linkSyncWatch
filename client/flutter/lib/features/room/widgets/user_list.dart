import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../../../providers/room_provider.dart';
import '../../../providers/download_provider.dart';

class UserListWidget extends ConsumerWidget {
  const UserListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(currentRoomProvider);
    final users = roomState.users;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'USERS (${users.length})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                return _UserTile(
                  user: users[index],
                  isMe: users[index].userId == roomState.myUserId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserState user;
  final bool isMe;

  const _UserTile({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localDownloads = ref.watch(downloadProgressProvider);
    final isDownloading =
        !user.mediaState.isDownloaded && user.mediaState.downloadProgress > 0;

    // For the local user, grab byte-level info from the download service.
    int? downloaded;
    int? total;
    if (isMe && isDownloading && user.mediaState.mediaId != null) {
      final local = localDownloads[user.mediaState.mediaId];
      if (local != null) {
        downloaded = local.downloaded;
        total = local.total;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (user.isOperator)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'OP',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _getStatusText(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),

          // Download progress bar + details
          if (isDownloading) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: user.mediaState.downloadProgress / 100,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${user.mediaState.downloadProgress.toStringAsFixed(1)}%',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (downloaded != null && total != null && total > 0) ...[
                        const Spacer(),
                        Text(
                          '${_formatBytes(downloaded)} / ${_formatBytes(total)}',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (user.connection.status == 'disconnected') {
      return Icons.cloud_off;
    }
    if (!user.mediaState.isDownloaded) {
      return Icons.downloading;
    }
    if (user.playbackState.isSynced) {
      return Icons.check_circle;
    }
    return Icons.sync_problem;
  }

  Color _getStatusColor() {
    if (user.connection.status == 'disconnected') {
      return Colors.grey;
    }
    if (!user.mediaState.isDownloaded) {
      return Colors.orange;
    }
    if (user.playbackState.isSynced) {
      return Colors.green;
    }
    return Colors.red;
  }

  String _getStatusText() {
    if (user.connection.status == 'disconnected') {
      return 'disconnected';
    }
    if (!user.mediaState.isDownloaded) {
      if (user.mediaState.downloadProgress > 0) {
        return 'downloading';
      }
      return 'waiting for download';
    }
    if (user.playbackState.isSynced) {
      return 'synced';
    }
    return '${user.playbackState.drift.toStringAsFixed(1)}s drift';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
