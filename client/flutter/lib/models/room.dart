import 'media.dart';
import 'user.dart';

class RoomSettings {
  final bool waitForNewUsers;
  final double syncThreshold;
  final bool autoplayNext;

  const RoomSettings({
    this.waitForNewUsers = false,
    this.syncThreshold = 5,
    this.autoplayNext = true,
  });

  factory RoomSettings.fromJson(Map<String, dynamic> json) {
    return RoomSettings(
      waitForNewUsers: json['waitForNewUsers'] ?? false,
      syncThreshold: (json['syncThreshold'] ?? 5).toDouble(),
      autoplayNext: json['autoplayNext'] ?? true,
    );
  }
}

class PlaybackState {
  final String status; // idle, waiting, playing, paused
  final double currentTime;
  final int lastUpdated;

  const PlaybackState({
    this.status = 'idle',
    this.currentTime = 0,
    this.lastUpdated = 0,
  });

  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    return PlaybackState(
      status: json['status'] ?? 'idle',
      currentTime: (json['currentTime'] ?? 0).toDouble(),
      lastUpdated: json['lastUpdated'] ?? 0,
    );
  }
}

class Room {
  final String id;
  final String name;
  final String operatorId;
  final int capacity;
  final bool isPublic;
  final RoomSettings settings;
  final Media? currentMedia;
  final List<Media> queue;
  final PlaybackState playbackState;
  final List<UserState> users;

  const Room({
    required this.id,
    required this.name,
    required this.operatorId,
    this.capacity = 10,
    this.isPublic = true,
    this.settings = const RoomSettings(),
    this.currentMedia,
    this.queue = const [],
    this.playbackState = const PlaybackState(),
    this.users = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      operatorId: json['operatorId'] ?? '',
      capacity: json['capacity'] ?? 10,
      isPublic: json['isPublic'] ?? true,
      settings: json['settings'] != null
          ? RoomSettings.fromJson(json['settings'])
          : const RoomSettings(),
      currentMedia: json['currentMedia'] != null
          ? Media.fromJson(json['currentMedia'])
          : null,
      queue: json['queue'] != null
          ? (json['queue'] as List).map((m) => Media.fromJson(m)).toList()
          : [],
      playbackState: json['playbackState'] != null
          ? PlaybackState.fromJson(json['playbackState'])
          : const PlaybackState(),
      users: json['users'] != null
          ? (json['users'] as List).map((u) => UserState.fromJson(u)).toList()
          : [],
    );
  }

  Room copyWith({
    String? id,
    String? name,
    String? operatorId,
    int? capacity,
    bool? isPublic,
    RoomSettings? settings,
    Media? currentMedia,
    List<Media>? queue,
    PlaybackState? playbackState,
    List<UserState>? users,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      operatorId: operatorId ?? this.operatorId,
      capacity: capacity ?? this.capacity,
      isPublic: isPublic ?? this.isPublic,
      settings: settings ?? this.settings,
      currentMedia: currentMedia ?? this.currentMedia,
      queue: queue ?? this.queue,
      playbackState: playbackState ?? this.playbackState,
      users: users ?? this.users,
    );
  }
}

class RoomSummary {
  final String id;
  final String name;
  final int userCount;
  final int capacity;
  final String? currentMediaFilename;
  final double? currentMediaDuration;
  final String status;
  final double? currentTime;

  const RoomSummary({
    required this.id,
    required this.name,
    required this.userCount,
    required this.capacity,
    this.currentMediaFilename,
    this.currentMediaDuration,
    this.status = 'idle',
    this.currentTime,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    final currentMedia = json['currentMedia'];
    return RoomSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      userCount: json['userCount'] ?? 0,
      capacity: json['capacity'] ?? 10,
      currentMediaFilename:
          currentMedia is Map ? currentMedia['filename'] : null,
      currentMediaDuration: currentMedia is Map
          ? (currentMedia['duration'] as num?)?.toDouble()
          : null,
      status: json['status'] ?? 'idle',
      currentTime: (json['currentTime'] as num?)?.toDouble(),
    );
  }
}
