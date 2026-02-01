import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../models/room.dart';
import '../../models/media.dart';
import '../../models/user.dart';
import '../../models/chat_message.dart';

class SocketService {
  io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  // Connection events
  final _connectedController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectedController.stream;

  // Room events
  final _roomStateController = StreamController<Room>.broadcast();
  Stream<Room> get roomStateStream => _roomStateController.stream;

  final _usersUpdateController = StreamController<List<UserState>>.broadcast();
  Stream<List<UserState>> get usersUpdateStream =>
      _usersUpdateController.stream;

  final _userJoinedController = StreamController<UserState>.broadcast();
  Stream<UserState> get userJoinedStream => _userJoinedController.stream;

  final _userLeftController = StreamController<String>.broadcast();
  Stream<String> get userLeftStream => _userLeftController.stream;

  final _allReadyController = StreamController<void>.broadcast();
  Stream<void> get allReadyStream => _allReadyController.stream;

  // Playback events
  final _playController = StreamController<double>.broadcast();
  Stream<double> get playStream => _playController.stream;

  final _pauseController =
      StreamController<({double atTime, String? reason})>.broadcast();
  Stream<({double atTime, String? reason})> get pauseStream =>
      _pauseController.stream;

  final _seekController = StreamController<double>.broadcast();
  Stream<double> get seekStream => _seekController.stream;

  final _stopController = StreamController<void>.broadcast();
  Stream<void> get stopStream => _stopController.stream;

  final _forceResyncController = StreamController<double>.broadcast();
  Stream<double> get forceResyncStream => _forceResyncController.stream;

  final _syncCheckController =
      StreamController<({double operatorTime, int timestamp})>.broadcast();
  Stream<({double operatorTime, int timestamp})> get syncCheckStream =>
      _syncCheckController.stream;

  // Media events
  final _mediaChangedController = StreamController<Media>.broadcast();
  Stream<Media> get mediaChangedStream => _mediaChangedController.stream;

  final _mediaAddedController = StreamController<Media>.broadcast();
  Stream<Media> get mediaAddedStream => _mediaAddedController.stream;

  final _mediaRemovedController = StreamController<String>.broadcast();
  Stream<String> get mediaRemovedStream => _mediaRemovedController.stream;

  final _queueUpdateController = StreamController<List<Media>>.broadcast();
  Stream<List<Media>> get queueUpdateStream => _queueUpdateController.stream;

  // Chat events
  final _chatMessageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get chatMessageStream => _chatMessageController.stream;

  // Lobby events
  final _lobbyUpdateController =
      StreamController<List<RoomSummary>>.broadcast();
  Stream<List<RoomSummary>> get lobbyUpdateStream =>
      _lobbyUpdateController.stream;

  void connect(String serverUrl, String token) {
    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _connectedController.add(true);
    });

    _socket!.onDisconnect((_) {
      _connectedController.add(false);
    });

    _setupEventListeners();
  }

  void _setupEventListeners() {
    final s = _socket!;

    // Room events
    s.on('room:state', (data) {
      _roomStateController.add(Room.fromJson(Map<String, dynamic>.from(data)));
    });

    s.on('room:usersUpdate', (data) {
      final users = (data['users'] as List)
          .map((u) => UserState.fromJson(Map<String, dynamic>.from(u)))
          .toList();
      _usersUpdateController.add(users);
    });

    s.on('room:userJoined', (data) {
      _userJoinedController
          .add(UserState.fromJson(Map<String, dynamic>.from(data)));
    });

    s.on('room:userLeft', (data) {
      _userLeftController.add(data['userId'] as String);
    });

    s.on('room:allReady', (_) {
      _allReadyController.add(null);
    });

    // Playback events
    s.on('playback:play', (data) {
      _playController.add((data['atTime'] as num).toDouble());
    });

    s.on('playback:pause', (data) {
      _pauseController.add((
        atTime: (data['atTime'] as num).toDouble(),
        reason: data['reason'] as String?,
      ));
    });

    s.on('playback:seek', (data) {
      _seekController.add((data['toTime'] as num).toDouble());
    });

    s.on('playback:stop', (_) {
      _stopController.add(null);
    });

    s.on('sync:check', (data) {
      _syncCheckController.add((
        operatorTime: (data['operatorTime'] as num).toDouble(),
        timestamp: data['timestamp'] as int,
      ));
    });

    s.on('sync:forceResync', (data) {
      _forceResyncController.add((data['toTime'] as num).toDouble());
    });

    // Media events
    s.on('media:changed', (data) {
      _mediaChangedController
          .add(Media.fromJson(Map<String, dynamic>.from(data['currentMedia'])));
    });

    s.on('media:added', (data) {
      _mediaAddedController
          .add(Media.fromJson(Map<String, dynamic>.from(data['media'])));
    });

    s.on('media:removed', (data) {
      _mediaRemovedController.add(data['mediaId'] as String);
    });

    s.on('queue:updated', (data) {
      final queue = (data['queue'] as List)
          .map((m) => Media.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _queueUpdateController.add(queue);
    });

    // Chat events
    s.on('chat:message', (data) {
      _chatMessageController
          .add(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
    });

    // Lobby events
    s.on('lobby:update', (data) {
      final rooms = (data['rooms'] as List)
          .map((r) => RoomSummary.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      _lobbyUpdateController.add(rooms);
    });
  }

  // Client -> Server emissions

  void subscribeLobby() {
    _socket?.emit('lobby:subscribe');
  }

  void joinRoom(String roomId, String displayName) {
    _socket?.emit('room:join', {
      'roomId': roomId,
      'displayName': displayName,
    });
  }

  void leaveRoom(String roomId) {
    _socket?.emit('room:leave', {'roomId': roomId});
  }

  void reportDownloadStart(String roomId, String mediaId) {
    _socket?.emit('user:downloadStart', {
      'roomId': roomId,
      'mediaId': mediaId,
    });
  }

  void reportDownloadProgress(
      String roomId, String mediaId, double progress) {
    _socket?.emit('user:downloadProgress', {
      'roomId': roomId,
      'mediaId': mediaId,
      'progress': progress,
    });
  }

  void reportDownloadComplete(String roomId, String mediaId) {
    _socket?.emit('user:downloadComplete', {
      'roomId': roomId,
      'mediaId': mediaId,
    });
  }

  void reportDownloadError(String roomId, String mediaId, String error) {
    _socket?.emit('user:downloadError', {
      'roomId': roomId,
      'mediaId': mediaId,
      'error': error,
    });
  }

  void reportPlaybackTime(String roomId, double currentTime) {
    _socket?.emit('user:playbackUpdate', {
      'roomId': roomId,
      'currentTime': currentTime,
    });
  }

  // Operator actions

  void opPlay(String roomId, {double? atTime}) {
    _socket?.emit('op:play', {
      'roomId': roomId,
      if (atTime != null) 'atTime': atTime,
    });
  }

  void opPause(String roomId) {
    _socket?.emit('op:pause', {'roomId': roomId});
  }

  void opSeek(String roomId, double toTime) {
    _socket?.emit('op:seek', {
      'roomId': roomId,
      'toTime': toTime,
    });
  }

  void opStop(String roomId) {
    _socket?.emit('op:stop', {'roomId': roomId});
  }

  void opAddMediaUrl(String roomId, String url, String filename) {
    _socket?.emit('op:addMediaUrl', {
      'roomId': roomId,
      'url': url,
      'filename': filename,
    });
  }

  void opRemoveMedia(String roomId, String mediaId) {
    _socket?.emit('op:removeMedia', {
      'roomId': roomId,
      'mediaId': mediaId,
    });
  }

  void opQueueNext(String roomId) {
    _socket?.emit('op:queueNext', {'roomId': roomId});
  }

  // Chat

  void chatSend(String roomId, String content) {
    _socket?.emit('chat:send', {
      'roomId': roomId,
      'content': content,
    });
  }

  void chatHistory(
    String roomId, {
    int? before,
    int limit = 50,
    String? type,
    required void Function(List<ChatMessage> messages) onResponse,
  }) {
    final data = <String, dynamic>{
      'roomId': roomId,
      'limit': limit,
    };
    if (before != null) data['before'] = before;
    if (type != null) data['type'] = type;

    _socket?.emitWithAck('chat:history', data, ack: (response) {
      if (response is Map) {
        final messages = (response['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        onResponse(messages);
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _connectedController.close();
    _roomStateController.close();
    _usersUpdateController.close();
    _userJoinedController.close();
    _userLeftController.close();
    _allReadyController.close();
    _playController.close();
    _pauseController.close();
    _seekController.close();
    _stopController.close();
    _forceResyncController.close();
    _syncCheckController.close();
    _mediaChangedController.close();
    _mediaAddedController.close();
    _mediaRemovedController.close();
    _queueUpdateController.close();
    _chatMessageController.close();
    _lobbyUpdateController.close();
  }
}
