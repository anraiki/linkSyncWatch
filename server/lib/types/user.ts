export interface UserMediaState {
  mediaId: string | null;
  downloadProgress: number;
  isDownloaded: boolean;
}

export interface UserPlaybackState {
  currentTime: number;
  isPlaying: boolean;
  isSynced: boolean;
  drift: number;
}

export interface UserConnection {
  status: "connected" | "disconnected";
  lastHeartbeat: number;
}

export interface UserState {
  userId: string;
  displayName: string;
  roomId: string;
  isOperator: boolean;
  mediaState: UserMediaState;
  playbackState: UserPlaybackState;
  connection: UserConnection;
}
