class UserMediaState {
  final String? mediaId;
  final double downloadProgress;
  final bool isDownloaded;

  const UserMediaState({
    this.mediaId,
    this.downloadProgress = 0,
    this.isDownloaded = false,
  });

  factory UserMediaState.fromJson(Map<String, dynamic> json) {
    return UserMediaState(
      mediaId: json['mediaId'],
      downloadProgress: (json['downloadProgress'] ?? 0).toDouble(),
      isDownloaded: json['isDownloaded'] ?? false,
    );
  }
}

class UserPlaybackState {
  final double currentTime;
  final bool isPlaying;
  final bool isSynced;
  final double drift;

  const UserPlaybackState({
    this.currentTime = 0,
    this.isPlaying = false,
    this.isSynced = true,
    this.drift = 0,
  });

  factory UserPlaybackState.fromJson(Map<String, dynamic> json) {
    return UserPlaybackState(
      currentTime: (json['currentTime'] ?? 0).toDouble(),
      isPlaying: json['isPlaying'] ?? false,
      isSynced: json['isSynced'] ?? true,
      drift: (json['drift'] ?? 0).toDouble(),
    );
  }
}

class UserConnection {
  final String status;
  final int lastHeartbeat;

  const UserConnection({
    this.status = 'connected',
    this.lastHeartbeat = 0,
  });

  factory UserConnection.fromJson(Map<String, dynamic> json) {
    return UserConnection(
      status: json['status'] ?? 'connected',
      lastHeartbeat: json['lastHeartbeat'] ?? 0,
    );
  }
}

class UserState {
  final String userId;
  final String displayName;
  final String roomId;
  final bool isOperator;
  final UserMediaState mediaState;
  final UserPlaybackState playbackState;
  final UserConnection connection;

  const UserState({
    required this.userId,
    required this.displayName,
    this.roomId = '',
    this.isOperator = false,
    this.mediaState = const UserMediaState(),
    this.playbackState = const UserPlaybackState(),
    this.connection = const UserConnection(),
  });

  factory UserState.fromJson(Map<String, dynamic> json) {
    return UserState(
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? '',
      roomId: json['roomId'] ?? '',
      isOperator: json['isOperator'] ?? false,
      mediaState: json['mediaState'] != null
          ? UserMediaState.fromJson(json['mediaState'])
          : const UserMediaState(),
      playbackState: json['playbackState'] != null
          ? UserPlaybackState.fromJson(json['playbackState'])
          : const UserPlaybackState(),
      connection: json['connection'] != null
          ? UserConnection.fromJson(json['connection'])
          : const UserConnection(),
    );
  }
}
