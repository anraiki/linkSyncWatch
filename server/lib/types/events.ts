import type { RoomState, RoomSummary, Media, ChatMessage } from "./room";
import type { UserState } from "./user";

export interface ServerToClientEvents {
  // Room
  "room:state": (state: RoomState & { users: UserState[] }) => void;
  "room:userJoined": (user: UserState) => void;
  "room:userLeft": (data: { userId: string }) => void;
  "room:usersUpdate": (data: { users: UserState[] }) => void;
  "room:allReady": () => void;

  // Playback
  "playback:play": (data: { atTime: number }) => void;
  "playback:pause": (data: { atTime: number; reason?: string }) => void;
  "playback:seek": (data: { toTime: number }) => void;
  "playback:stop": () => void;

  // Media
  "media:added": (data: { media: Media }) => void;
  "media:removed": (data: { mediaId: string }) => void;
  "media:changed": (data: { currentMedia: Media }) => void;
  "queue:updated": (data: { queue: Media[] }) => void;

  // Sync
  "sync:check": (data: { operatorTime: number; timestamp: number }) => void;
  "sync:forceResync": (data: { toTime: number }) => void;

  // Chat
  "chat:message": (data: ChatMessage) => void;
  "chat:history": (data: { messages: ChatMessage[] }) => void;

  // Lobby
  "lobby:update": (data: { rooms: RoomSummary[] }) => void;
}

export interface ClientToServerEvents {
  // Room
  "room:join": (
    data: { roomId: string; displayName: string },
    callback?: (response: { success: boolean; error?: string }) => void
  ) => void;
  "room:leave": (data: { roomId: string }) => void;

  // Download lifecycle
  "user:downloadStart": (data: { roomId: string; mediaId: string }) => void;
  "user:downloadProgress": (data: {
    roomId: string;
    mediaId: string;
    progress: number;
  }) => void;
  "user:downloadComplete": (data: { roomId: string; mediaId: string }) => void;
  "user:downloadError": (data: {
    roomId: string;
    mediaId: string;
    error: string;
  }) => void;

  // Playback
  "user:playbackUpdate": (data: {
    roomId: string;
    currentTime: number;
  }) => void;

  // Operator actions
  "op:play": (data: { roomId: string; atTime?: number }) => void;
  "op:pause": (data: { roomId: string }) => void;
  "op:seek": (data: { roomId: string; toTime: number }) => void;
  "op:stop": (data: { roomId: string }) => void;
  "op:addMediaUrl": (data: {
    roomId: string;
    url: string;
    filename: string;
  }) => void;
  "op:removeMedia": (data: { roomId: string; mediaId: string }) => void;
  "op:queueNext": (data: { roomId: string }) => void;

  // Chat
  "chat:send": (data: { roomId: string; content: string }) => void;
  "chat:history": (
    data: { roomId: string; before?: number; limit?: number; type?: "user" | "system" },
    callback: (response: { messages: ChatMessage[] }) => void
  ) => void;

  // Lobby
  "lobby:subscribe": () => void;
}

export interface SocketData {
  userId: string;
  displayName: string;
  guest: boolean;
}
