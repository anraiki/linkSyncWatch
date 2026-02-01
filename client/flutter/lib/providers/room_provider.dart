import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/media.dart';
import '../models/user.dart';
import 'socket_provider.dart';
import 'player_provider.dart';
import 'download_provider.dart';
import 'auth_provider.dart';

class RoomViewState {
  final Room? room;
  final List<UserState> users;
  final bool isOperator;
  final String? myUserId;

  const RoomViewState({
    this.room,
    this.users = const [],
    this.isOperator = false,
    this.myUserId,
  });

  RoomViewState copyWith({
    Room? room,
    List<UserState>? users,
    bool? isOperator,
    String? myUserId,
  }) {
    return RoomViewState(
      room: room ?? this.room,
      users: users ?? this.users,
      isOperator: isOperator ?? this.isOperator,
      myUserId: myUserId ?? this.myUserId,
    );
  }
}

final currentRoomProvider =
    StateNotifierProvider<RoomNotifier, RoomViewState>((ref) {
  return RoomNotifier(ref);
});

class RoomNotifier extends StateNotifier<RoomViewState> {
  final Ref _ref;
  final List<StreamSubscription> _subs = [];
  Timer? _playbackReportTimer;

  RoomNotifier(this._ref) : super(const RoomViewState()) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socket = _ref.read(socketServiceProvider);
    final player = _ref.read(playerServiceProvider);

    _subs.add(socket.roomStateStream.listen((room) {
      final auth = _ref.read(authStateProvider);
      final isOp = room.operatorId == auth.userId;
      state = RoomViewState(
        room: room,
        users: room.users,
        isOperator: isOp,
        myUserId: auth.userId,
      );

      // Start downloading current media if available
      if (room.currentMedia != null) {
        _startMediaDownload(room.currentMedia!);
      }
    }));

    _subs.add(socket.usersUpdateStream.listen((users) {
      if (state.room != null) {
        final auth = _ref.read(authStateProvider);
        final isOp =
            users.any((u) => u.userId == auth.userId && u.isOperator);
        state = state.copyWith(users: users, isOperator: isOp);
      }
    }));

    _subs.add(socket.userJoinedStream.listen((user) {
      if (state.room != null) {
        state = state.copyWith(users: [...state.users, user]);
      }
    }));

    _subs.add(socket.userLeftStream.listen((userId) {
      if (state.room != null) {
        state = state.copyWith(
          users: state.users.where((u) => u.userId != userId).toList(),
        );
      }
    }));

    _subs.add(socket.playStream.listen((atTime) async {
      if (!_ref.read(syncEnabledProvider)) return;
      await player.seek(Duration(milliseconds: (atTime * 1000).toInt()));
      await player.play();
      _startPlaybackReporting();
    }));

    _subs.add(socket.pauseStream.listen((data) async {
      if (!_ref.read(syncEnabledProvider)) return;
      await player.pause();
      await player
          .seek(Duration(milliseconds: (data.atTime * 1000).toInt()));
      _stopPlaybackReporting();
    }));

    _subs.add(socket.seekStream.listen((toTime) async {
      if (!_ref.read(syncEnabledProvider)) return;
      await player.seek(Duration(milliseconds: (toTime * 1000).toInt()));
    }));

    _subs.add(socket.stopStream.listen((_) async {
      if (!_ref.read(syncEnabledProvider)) return;
      await player.stop();
      _stopPlaybackReporting();
    }));

    _subs.add(socket.forceResyncStream.listen((toTime) async {
      // Force resync always applies regardless of toggle.
      await player.seek(Duration(milliseconds: (toTime * 1000).toInt()));
    }));

    _subs.add(socket.mediaChangedStream.listen((media) {
      if (state.room != null) {
        state = state.copyWith(
          room: state.room!.copyWith(currentMedia: media),
        );
        _startMediaDownload(media);
      }
    }));

    _subs.add(socket.queueUpdateStream.listen((queue) {
      if (state.room != null) {
        state = state.copyWith(
          room: state.room!.copyWith(queue: queue),
        );
      }
    }));
  }

  Future<void> _startMediaDownload(Media media) async {
    final downloadService = _ref.read(downloadServiceProvider);
    final socket = _ref.read(socketServiceProvider);
    final api = _ref.read(apiClientProvider);
    final player = _ref.read(playerServiceProvider);
    final roomId = state.room!.id;

    // Initialize player early so the Video widget can mount with the controller.
    // On Windows, the controller must be attached before media is loaded.
    await player.initialize();
    _ref.read(playerReadyProvider.notifier).state = true;

    // Wait for the next frame so the Video widget actually mounts and attaches
    // to the VideoController. Without this, player.open() on Windows finds no
    // video output surface and renders audio-only (black screen).
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    await completer.future;

    final url = media.source.type == 'external' && media.source.url != null
        ? media.source.url!
        : api.getMediaDownloadUrl(media.id);

    downloadService.setAuthToken(_ref.read(authStateProvider).token);

    socket.reportDownloadStart(roomId, media.id);

    downloadService.onProgress = (progress) {
      socket.reportDownloadProgress(roomId, media.id, progress.progress);
    };

    final filePath =
        await downloadService.startDownload(url, media.id, media.filename);

    if (filePath != null) {
      socket.reportDownloadComplete(roomId, media.id);
      await player.loadFile(filePath);
      // Sync to the room's current playback state instead of auto-playing.
      await _syncToRoomState();
    } else {
      socket.reportDownloadError(roomId, media.id, 'Download failed');
    }
  }

  Future<void> _syncToRoomState() async {
    final room = state.room;
    if (room == null) return;

    final player = _ref.read(playerServiceProvider);
    final pb = room.playbackState;
    final seekTo = Duration(milliseconds: (pb.currentTime * 1000).toInt());

    if (pb.status == 'playing') {
      // Estimate where playback should be now based on wall-clock elapsed time.
      final elapsed = DateTime.now().millisecondsSinceEpoch - pb.lastUpdated;
      final estimatedMs = (pb.currentTime * 1000).toInt() + elapsed;
      await player.seek(Duration(milliseconds: estimatedMs));
      await player.play();
      _startPlaybackReporting();
    } else if (pb.status == 'paused' || pb.status == 'waiting') {
      await player.seek(seekTo);
      await player.pause();
    }
    // For 'idle', do nothing — file is loaded but no playback.
  }

  void _startPlaybackReporting() {
    _stopPlaybackReporting();
    _playbackReportTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (state.room != null) {
          final player = _ref.read(playerServiceProvider);
          final socket = _ref.read(socketServiceProvider);
          socket.reportPlaybackTime(
            state.room!.id,
            player.position.inMilliseconds / 1000,
          );
        }
      },
    );
  }

  void _stopPlaybackReporting() {
    _playbackReportTimer?.cancel();
    _playbackReportTimer = null;
  }

  /// Re-sync local player to the room's current playback state.
  Future<void> resync() async {
    await _syncToRoomState();
  }

  void joinRoom(String roomId, String displayName) {
    _ref.read(socketServiceProvider).joinRoom(roomId, displayName);
  }

  void leaveRoom() {
    if (state.room != null) {
      _stopPlaybackReporting();
      _ref.read(socketServiceProvider).leaveRoom(state.room!.id);
      _ref.read(playerReadyProvider.notifier).state = false;
      state = const RoomViewState();
    }
  }

  // Operator actions

  void play({double? atTime}) {
    if (state.room != null) {
      _ref.read(socketServiceProvider).opPlay(state.room!.id, atTime: atTime);
    }
  }

  void pause() {
    if (state.room != null) {
      _ref.read(socketServiceProvider).opPause(state.room!.id);
    }
  }

  void seek(double toTime) {
    if (state.room != null) {
      _ref.read(socketServiceProvider).opSeek(state.room!.id, toTime);
    }
  }

  void stop() {
    if (state.room != null) {
      _ref.read(socketServiceProvider).opStop(state.room!.id);
    }
  }

  void addMediaUrl(String url, String filename) {
    if (state.room != null) {
      _ref
          .read(socketServiceProvider)
          .opAddMediaUrl(state.room!.id, url, filename);
    }
  }

  void removeMedia(String mediaId) {
    if (state.room != null) {
      _ref
          .read(socketServiceProvider)
          .opRemoveMedia(state.room!.id, mediaId);
    }
  }

  void queueNext() {
    if (state.room != null) {
      _ref.read(socketServiceProvider).opQueueNext(state.room!.id);
    }
  }

  @override
  void dispose() {
    _stopPlaybackReporting();
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}

final lobbyRoomsProvider =
    StateNotifierProvider<LobbyNotifier, List<RoomSummary>>((ref) {
  return LobbyNotifier(ref);
});

class LobbyNotifier extends StateNotifier<List<RoomSummary>> {
  final Ref _ref;
  StreamSubscription? _sub;

  LobbyNotifier(this._ref) : super([]) {
    final socket = _ref.read(socketServiceProvider);
    _sub = socket.lobbyUpdateStream.listen((rooms) {
      state = rooms;
    });
  }

  void subscribe() {
    _ref.read(socketServiceProvider).subscribeLobby();
  }

  Future<void> fetchRooms() async {
    try {
      final api = _ref.read(apiClientProvider);
      final roomsJson = await api.getRooms();
      state = roomsJson.map((r) => RoomSummary.fromJson(r)).toList();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
