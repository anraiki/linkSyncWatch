export interface RoomSettings {
  waitForNewUsers: boolean;
  syncThreshold: number;
  autoplayNext: boolean;
}

export interface MediaSource {
  type: "server" | "external";
  path?: string;   // file path on server (when type = 'server')
  url?: string;    // external URL (when type = 'external')
}

export interface Media {
  id: string;
  filename: string;
  size: number;
  duration: number;
  source: MediaSource;
}

export interface PlaybackState {
  status: "idle" | "waiting" | "playing" | "paused";
  currentTime: number;
  lastUpdated: number;
}

export interface RoomState {
  id: string;
  name: string;
  operatorId: string;
  capacity: number;
  isPublic: boolean;
  settings: RoomSettings;
  currentMedia: Media | null;
  queue: Media[];
  playbackState: PlaybackState;
}

export interface ChatMessage {
  id: string;
  roomId: string;
  userId: string;
  displayName: string;
  content: string;
  type: "user" | "system";
  timestamp: number;
}

export interface RoomSummary {
  id: string;
  name: string;
  userCount: number;
  capacity: number;
  currentMedia: {
    filename: string;
    duration?: number;
  } | null;
  status: "idle" | "waiting" | "playing" | "paused";
  currentTime?: number;
}
