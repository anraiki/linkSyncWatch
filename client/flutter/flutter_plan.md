# SyncWatch Flutter Client Prototype

## Overview
Cross-platform client for SyncWatch using Flutter + media_kit for native video playback.

**Reference:** https://github.com/media-kit/media-kit

---

## Tech Stack

```
├── Framework: Flutter 3.x
├── Video: media_kit (wraps libmpv)
├── Sync: socket_io_client
├── State: Riverpod
├── HTTP: dio (downloads with progress)
└── Storage: path_provider + sqflite
```

---

## Dependencies

### pubspec.yaml
```yaml
name: syncwatch
description: Synchronized media watch party app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # Video playback
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4          # Bundles libmpv for all platforms
  
  # Networking
  socket_io_client: ^2.0.3
  dio: ^5.4.0
  
  # State management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  
  # Storage & paths
  path_provider: ^2.1.1
  sqflite: ^2.3.0
  
  # UI
  flutter_hooks: ^0.20.3
  hooks_riverpod: ^2.4.9
  go_router: ^13.0.0
  
  # Utils
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.7
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  riverpod_generator: ^2.3.9

flutter:
  uses-material-design: true
```

---

## Project Structure

```
syncwatch_flutter/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── router.dart
│   │
│   ├── features/
│   │   ├── lobby/
│   │   │   ├── lobby_screen.dart
│   │   │   ├── lobby_controller.dart
│   │   │   └── widgets/
│   │   │       └── room_card.dart
│   │   │
│   │   ├── room/
│   │   │   ├── room_screen.dart
│   │   │   ├── room_controller.dart
│   │   │   └── widgets/
│   │   │       ├── player_widget.dart
│   │   │       ├── user_list.dart
│   │   │       ├── queue_list.dart
│   │   │       └── operator_controls.dart
│   │   │
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       └── settings_controller.dart
│   │
│   ├── core/
│   │   ├── socket/
│   │   │   ├── socket_service.dart
│   │   │   └── socket_events.dart
│   │   ├── download/
│   │   │   ├── download_service.dart
│   │   │   └── download_state.dart
│   │   ├── player/
│   │   │   ├── player_service.dart
│   │   │   └── player_state.dart
│   │   └── api/
│   │       └── api_client.dart
│   │
│   ├── models/
│   │   ├── room.dart
│   │   ├── user.dart
│   │   ├── media.dart
│   │   └── events.dart
│   │
│   ├── providers/
│   │   ├── socket_provider.dart
│   │   ├── player_provider.dart
│   │   ├── room_provider.dart
│   │   └── download_provider.dart
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── loading_indicator.dart
│       │   └── error_view.dart
│       └── utils/
│           └── formatters.dart
│
├── assets/
│   └── images/
│
├── android/
├── ios/
├── macos/
├── windows/
├── linux/
└── pubspec.yaml
```

---

## Core Components

### 1. Media Kit Player Service

```dart
// lib/core/player/player_service.dart
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerService {
  late final Player player;
  late final VideoController videoController;
  
  bool _isInitialized = false;
  
  // Streams for state
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
        bufferSize: 64 * 1024 * 1024, // 64MB buffer
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

  Future<void> loadFile(String path) async {
    await player.open(Media(path));
  }

  Future<void> loadUrl(String url) async {
    await player.open(Media(url));
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

  Future<void> dispose() async {
    await player.dispose();
  }
}
```

### 2. Socket Service

```dart
// lib/core/socket/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:syncwatch/models/room.dart';
import 'package:syncwatch/models/user.dart';

class SocketService {
  IO.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  // Event callbacks
  Function(Room)? onRoomState;
  Function(List<UserState>)? onUsersUpdate;
  Function(double)? onPlay;
  Function(double)? onPause;
  Function(double)? onSeek;
  Function(double)? onForceResync;
  Function(Media)? onMediaChanged;
  Function(List<Media>)? onQueueUpdate;

  void connect(String serverUrl) {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Room events
    _socket!.on('room:state', (data) {
      onRoomState?.call(Room.fromJson(data));
    });

    _socket!.on('room:usersUpdate', (data) {
      final users = (data['users'] as List)
          .map((u) => UserState.fromJson(u))
          .toList();
      onUsersUpdate?.call(users);
    });

    // Playback events
    _socket!.on('playback:play', (data) {
      onPlay?.call((data['atTime'] as num).toDouble());
    });

    _socket!.on('playback:pause', (data) {
      onPause?.call((data['atTime'] as num).toDouble());
    });

    _socket!.on('playback:seek', (data) {
      onSeek?.call((data['toTime'] as num).toDouble());
    });

    _socket!.on('sync:forceResync', (data) {
      onForceResync?.call((data['toTime'] as num).toDouble());
    });

    // Media events
    _socket!.on('media:changed', (data) {
      onMediaChanged?.call(Media.fromJson(data['currentMedia']));
    });

    _socket!.on('queue:updated', (data) {
      final queue = (data['queue'] as List)
          .map((m) => Media.fromJson(m))
          .toList();
      onQueueUpdate?.call(queue);
    });
  }

  // Lobby
  void subscribeLobby() {
    _socket!.emit('lobby:subscribe');
  }

  // Room actions
  void joinRoom(String roomId, String displayName) {
    _socket!.emit('room:join', {
      'roomId': roomId,
      'displayName': displayName,
    });
  }

  void leaveRoom(String roomId) {
    _socket!.emit('room:leave', {'roomId': roomId});
  }

  // User state updates
  void reportDownloadProgress(String roomId, String mediaId, double progress) {
    _socket!.emit('user:downloadProgress', {
      'roomId': roomId,
      'mediaId': mediaId,
      'progress': progress,
    });
  }

  void reportReady(String roomId, String mediaId) {
    _socket!.emit('user:ready', {
      'roomId': roomId,
      'mediaId': mediaId,
    });
  }

  void reportPlaybackTime(String roomId, double currentTime) {
    _socket!.emit('user:playbackUpdate', {
      'roomId': roomId,
      'currentTime': currentTime,
    });
  }

  // Operator actions
  void opPlay(String roomId, {double? atTime}) {
    _socket!.emit('op:play', {
      'roomId': roomId,
      if (atTime != null) 'atTime': atTime,
    });
  }

  void opPause(String roomId) {
    _socket!.emit('op:pause', {'roomId': roomId});
  }

  void opSeek(String roomId, double toTime) {
    _socket!.emit('op:seek', {
      'roomId': roomId,
      'toTime': toTime,
    });
  }

  void opAddMediaUrl(String roomId, String url, String filename) {
    _socket!.emit('op:addMediaUrl', {
      'roomId': roomId,
      'url': url,
      'filename': filename,
    });
  }

  void opQueueNext(String roomId) {
    _socket!.emit('op:queueNext', {'roomId': roomId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
```

### 3. Download Service

```dart
// lib/core/download/download_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DownloadProgress {
  final String mediaId;
  final double progress;
  final int downloaded;
  final int total;
  final DownloadStatus status;

  DownloadProgress({
    required this.mediaId,
    required this.progress,
    required this.downloaded,
    required this.total,
    required this.status,
  });
}

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class DownloadService {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DownloadProgress> _downloads = {};

  Function(DownloadProgress)? onProgress;

  Future<String> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'SyncWatch', 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  Future<String?> startDownload(String url, String mediaId, String filename) async {
    final mediaDir = await getMediaDirectory();
    final filePath = p.join(mediaDir, filename);
    final file = File(filePath);

    // Check if already downloaded
    if (await file.exists()) {
      _updateProgress(mediaId, DownloadProgress(
        mediaId: mediaId,
        progress: 100,
        downloaded: await file.length(),
        total: await file.length(),
        status: DownloadStatus.completed,
      ));
      return filePath;
    }

    final cancelToken = CancelToken();
    _cancelTokens[mediaId] = cancelToken;

    try {
      _updateProgress(mediaId, DownloadProgress(
        mediaId: mediaId,
        progress: 0,
        downloaded: 0,
        total: 0,
        status: DownloadStatus.downloading,
      ));

      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? (received / total) * 100 : 0.0;
          _updateProgress(mediaId, DownloadProgress(
            mediaId: mediaId,
            progress: progress,
            downloaded: received,
            total: total,
            status: DownloadStatus.downloading,
          ));
        },
      );

      _updateProgress(mediaId, DownloadProgress(
        mediaId: mediaId,
        progress: 100,
        downloaded: await file.length(),
        total: await file.length(),
        status: DownloadStatus.completed,
      ));

      return filePath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _updateProgress(mediaId, DownloadProgress(
          mediaId: mediaId,
          progress: 0,
          downloaded: 0,
          total: 0,
          status: DownloadStatus.cancelled,
        ));
      } else {
        _updateProgress(mediaId, DownloadProgress(
          mediaId: mediaId,
          progress: 0,
          downloaded: 0,
          total: 0,
          status: DownloadStatus.failed,
        ));
      }
      return null;
    } finally {
      _cancelTokens.remove(mediaId);
    }
  }

  void cancelDownload(String mediaId) {
    _cancelTokens[mediaId]?.cancel();
  }

  Future<void> deleteMedia(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> cleanupAllMedia() async {
    final mediaDir = await getMediaDirectory();
    final dir = Directory(mediaDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  DownloadProgress? getProgress(String mediaId) => _downloads[mediaId];

  void _updateProgress(String mediaId, DownloadProgress progress) {
    _downloads[mediaId] = progress;
    onProgress?.call(progress);
  }
}
```

### 4. Room Provider (Riverpod)

```dart
// lib/providers/room_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncwatch/models/room.dart';
import 'package:syncwatch/models/user.dart';
import 'package:syncwatch/providers/socket_provider.dart';
import 'package:syncwatch/providers/player_provider.dart';
import 'package:syncwatch/providers/download_provider.dart';

final currentRoomProvider = StateNotifierProvider<RoomNotifier, RoomState?>((ref) {
  return RoomNotifier(ref);
});

class RoomNotifier extends StateNotifier<RoomState?> {
  final Ref _ref;

  RoomNotifier(this._ref) : super(null) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socket = _ref.read(socketServiceProvider);
    final player = _ref.read(playerServiceProvider);

    socket.onRoomState = (room) {
      state = RoomState(
        room: room,
        users: room.users,
        isOperator: false, // Set based on current user ID
      );
    };

    socket.onUsersUpdate = (users) {
      if (state != null) {
        state = state!.copyWith(users: users);
      }
    };

    socket.onPlay = (atTime) async {
      await player.seek(Duration(milliseconds: (atTime * 1000).toInt()));
      await player.play();
    };

    socket.onPause = (atTime) async {
      await player.pause();
      await player.seek(Duration(milliseconds: (atTime * 1000).toInt()));
    };

    socket.onSeek = (toTime) async {
      await player.seek(Duration(milliseconds: (toTime * 1000).toInt()));
    };

    socket.onForceResync = (toTime) async {
      await player.seek(Duration(milliseconds: (toTime * 1000).toInt()));
    };
  }

  void joinRoom(String roomId, String displayName) {
    _ref.read(socketServiceProvider).joinRoom(roomId, displayName);
  }

  void leaveRoom() {
    if (state != null) {
      _ref.read(socketServiceProvider).leaveRoom(state!.room.id);
      state = null;
    }
  }

  // Operator actions
  void play({double? atTime}) {
    if (state != null) {
      _ref.read(socketServiceProvider).opPlay(state!.room.id, atTime: atTime);
    }
  }

  void pause() {
    if (state != null) {
      _ref.read(socketServiceProvider).opPause(state!.room.id);
    }
  }

  void seek(double toTime) {
    if (state != null) {
      _ref.read(socketServiceProvider).opSeek(state!.room.id, toTime);
    }
  }
}

class RoomState {
  final Room room;
  final List<UserState> users;
  final bool isOperator;

  RoomState({
    required this.room,
    required this.users,
    required this.isOperator,
  });

  RoomState copyWith({
    Room? room,
    List<UserState>? users,
    bool? isOperator,
  }) {
    return RoomState(
      room: room ?? this.room,
      users: users ?? this.users,
      isOperator: isOperator ?? this.isOperator,
    );
  }
}
```

### 5. Player Widget

```dart
// lib/features/room/widgets/player_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:syncwatch/providers/player_provider.dart';
import 'package:syncwatch/providers/room_provider.dart';

class PlayerWidget extends ConsumerWidget {
  const PlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(playerServiceProvider);
    final roomState = ref.watch(currentRoomProvider);
    final isOperator = roomState?.isOperator ?? false;

    return Column(
      children: [
        // Video display
        Expanded(
          child: Video(
            controller: playerService.videoController,
            controls: NoVideoControls, // We use custom controls
          ),
        ),

        // Custom controls (only functional for operator)
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

    return StreamBuilder<Duration>(
      stream: playerService.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: playerService.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            return Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  Slider(
                    value: position.inMilliseconds.toDouble(),
                    max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: isOperator
                        ? (value) {
                            roomNotifier.seek(value / 1000);
                          }
                        : null,
                  ),

                  // Time display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Play/Pause button
                  StreamBuilder<bool>(
                    stream: playerService.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;

                      return IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: isOperator ? Colors.white : Colors.grey,
                          size: 48,
                        ),
                        onPressed: isOperator
                            ? () {
                                if (isPlaying) {
                                  roomNotifier.pause();
                                } else {
                                  roomNotifier.play(
                                    atTime: position.inMilliseconds / 1000,
                                  );
                                }
                              }
                            : null,
                      );
                    },
                  ),

                  if (!isOperator)
                    const Text(
                      'Only the operator can control playback',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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
```

### 6. User List Widget

```dart
// lib/features/room/widgets/user_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncwatch/models/user.dart';
import 'package:syncwatch/providers/room_provider.dart';

class UserListWidget extends ConsumerWidget {
  const UserListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(currentRoomProvider);
    final users = roomState?.users ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'USERS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                return _UserTile(user: users[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserState user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Status icon
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 16,
          ),
          const SizedBox(width: 8),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (user.isOperator)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          '(operator)',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                Text(
                  _getStatusText(),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Download progress bar (if downloading)
          if (!user.mediaState.isDownloaded && user.mediaState.downloadProgress > 0)
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: user.mediaState.downloadProgress / 100,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (!user.mediaState.isDownloaded) {
      return Icons.downloading;
    }
    if (user.playbackState.isSynced) {
      return Icons.check_circle;
    }
    return Icons.sync_problem;
  }

  Color _getStatusColor() {
    if (!user.mediaState.isDownloaded) {
      return Colors.orange;
    }
    if (user.playbackState.isSynced) {
      return Colors.green;
    }
    return Colors.red;
  }

  String _getStatusText() {
    if (!user.mediaState.isDownloaded) {
      return '${user.mediaState.downloadProgress.toInt()}%';
    }
    if (user.playbackState.isSynced) {
      return 'synced';
    }
    return '${user.playbackState.drift.toStringAsFixed(1)}s drift';
  }
}
```

---

## UI Screens

### Lobby Screen
```
┌─────────────────────────────────────────────────────────┐
│  SYNCWATCH                           [ + Create Room ] │
│  Server: syncwatch.example.com ✓                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🎬 THEATERS                                            │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │  Movie Night                        3/10 users │     │
│  │  Now playing: Inception.mkv                    │     │
│  │  Status: Playing (1:23:45)          [ Join ]   │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │  Anime Sundays                      5/10 users │     │
│  │  Now playing: S01E05.mkv                       │     │
│  │  Status: Waiting                    [ Join ]   │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Room Screen
```
┌─────────────────────────────────────────────────────────┐
│  ← Back    Movie Night                    ⚙️ Settings   │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐   │
│  │                                                  │   │
│  │              VIDEO PLAYER (media_kit)            │   │
│  │                                                  │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│   advancement bar... [▶ play/pause] [seek] (op only)    │
├──────────────────────┬──────────────────────────────────┤
│  USERS               │  NOW PLAYING                     │
│                      │  Inception.mkv                   │
│  ✓ Anri (operator)   │                                  │
│    100% | synced     │  QUEUE                           │
│                      │  1. Movie2.mkv                   │
│  ✓ John              │  2. Movie3.mkv                   │
│    100% | synced     │                                  │
│                      │  [ + Add Media ]  (op only)      │
│  ⟳ Mike              │                                  │
│    67% ████████░░░░  │                                  │
│                      │                                  │
└──────────────────────┴──────────────────────────────────┘
```

---

## Platform Setup

### media_kit handles libmpv bundling automatically!

The `media_kit_libs_video` package bundles libmpv for all platforms:
- **Windows**: Included in package
- **macOS**: Included in package  
- **Linux**: Included in package
- **iOS**: Uses native AVPlayer (no libmpv needed)
- **Android**: Uses native MediaPlayer or ExoPlayer

No manual libmpv installation required!

### Platform-specific setup

**Android** (`android/app/build.gradle`):
```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

**iOS** (`ios/Podfile`):
```ruby
platform :ios, '13.0'
```

**macOS** (`macos/Runner/Release.entitlements`):
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

**Linux**: Install required libs:
```bash
sudo apt install libmpv-dev
```

---

## Installer Scripts

Since Flutter bundles everything, installers are simpler:

### macOS
```bash
#!/bin/bash
# curl -fsSL https://syncwatch.app/install.sh | bash

APP_NAME="SyncWatch"
APP_URL="https://syncwatch.app/releases/latest/SyncWatch.dmg"

echo "╔════════════════════════════════════════╗"
echo "║         $APP_NAME Installer            ║"
echo "╚════════════════════════════════════════╝"

read -p "Install $APP_NAME? (y/n): " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0

echo "Downloading..."
curl -fSL "$APP_URL" -o "/tmp/$APP_NAME.dmg"

echo "Installing..."
MOUNT=$(hdiutil attach "/tmp/$APP_NAME.dmg" -nobrowse | grep "/Volumes" | awk '{print $3}')
cp -R "$MOUNT/$APP_NAME.app" /Applications/
hdiutil detach "$MOUNT" -quiet
rm "/tmp/$APP_NAME.dmg"

echo "✓ Done! Launch from Applications."
read -p "Open now? (y/n): " open
[[ "$open" =~ ^[Yy]$ ]] && open "/Applications/$APP_NAME.app"
```

### Windows
```powershell
# irm https://syncwatch.app/install.ps1 | iex

$AppName = "SyncWatch"
$AppUrl = "https://syncwatch.app/releases/latest/SyncWatch_x64.msi"

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         $AppName Installer              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan

$confirm = Read-Host "Install $AppName? (y/n)"
if ($confirm -notmatch "^[Yy]$") { exit 0 }

Write-Host "Downloading..."
$MsiPath = "$env:TEMP\$AppName.msi"
Invoke-WebRequest -Uri $AppUrl -OutFile $MsiPath

Write-Host "Installing..."
Start-Process msiexec.exe -ArgumentList "/i `"$MsiPath`" /quiet" -Wait
Remove-Item $MsiPath

Write-Host "✓ Done!" -ForegroundColor Green
$open = Read-Host "Open $AppName? (y/n)"
if ($open -match "^[Yy]$") { Start-Process "$env:ProgramFiles\$AppName\$AppName.exe" }
```

### Linux
```bash
#!/bin/bash
# curl -fsSL https://syncwatch.app/install-linux.sh | bash

APP_NAME="SyncWatch"
DEB_URL="https://syncwatch.app/releases/latest/syncwatch_amd64.deb"

echo "╔════════════════════════════════════════╗"
echo "║         $APP_NAME Installer            ║"
echo "╚════════════════════════════════════════╝"

read -p "Install $APP_NAME? (y/n): " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0

# Install libmpv if needed
if ! dpkg -l | grep -q libmpv; then
    echo "Installing libmpv..."
    sudo apt update && sudo apt install -y libmpv-dev
fi

echo "Downloading..."
curl -fSL "$DEB_URL" -o "/tmp/$APP_NAME.deb"

echo "Installing..."
sudo apt install -y "/tmp/$APP_NAME.deb"
rm "/tmp/$APP_NAME.deb"

echo "✓ Done!"
```

---

## Sync Flow

```
1. User joins room
   └── Socket: room:join → receives room:state

2. User starts downloading current media
   └── DownloadService.startDownload() → emits progress
   └── Socket: user:downloadProgress (reports to server)

3. Download complete
   └── Socket: user:ready
   └── PlayerService.loadFile(path)

4. Operator hits play
   └── Socket: op:play → server broadcasts playback:play
   └── All clients: player.seek(time) + player.play()

5. Periodic sync (every 2-3 sec)
   └── Socket: user:playbackUpdate (report current time)
   └── Server checks drift, sends sync:forceResync if needed

6. Operator seeks/pauses
   └── Socket: op:seek/op:pause → broadcast to all
```

---

## Testing Checklist

- [ ] media_kit initializes and plays local file
- [ ] Socket connects to server
- [ ] Join room and receive state
- [ ] Download file with progress
- [ ] Load downloaded file into player
- [ ] Receive play/pause/seek commands
- [ ] Report playback position
- [ ] Force resync works
- [ ] Cleanup files on exit
- [ ] Works on Windows, macOS, Linux
- [ ] Works on iOS, Android (mobile)

---

## Comparison: Flutter vs Tauri

| Aspect | Flutter + media_kit | Tauri + libmpv |
|--------|---------------------|----------------|
| **Platforms** | iOS, Android, Windows, macOS, Linux | Windows, macOS, Linux (mobile experimental) |
| **libmpv setup** | Bundled automatically | Manual on macOS/Linux |
| **Bundle size** | ~15-25MB | ~10-15MB |
| **Mobile** | Native, production-ready | Experimental |
| **Learning curve** | Dart (you know it) | Rust + React |
| **Hot reload** | Yes | Yes (frontend only) |
| **Native feel** | Good (Material/Cupertino) | WebView-based |

**Recommendation:** Flutter if you want mobile support. Tauri if desktop-only and want smallest bundles.

---

## Notes

- media_kit bundles libmpv — no user setup required on any platform
- iOS uses AVPlayer under the hood, not libmpv (still works great)
- For large files (5-10GB), use chunked downloads with resume support
- Consider adding "buffer check" before play (everyone loaded?)
- Riverpod handles state nicely across the app
