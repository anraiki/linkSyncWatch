import type { RoomState, RoomSettings } from "../types/room";
import type { UserState } from "../types/user";

const rooms = new Map<string, RoomState>();
const users = new Map<string, UserState>();

const DEFAULT_SETTINGS: RoomSettings = {
  waitForNewUsers: false,
  syncThreshold: 5,
  autoplayNext: true,
};

export interface CreateRoomOptions {
  capacity?: number;
  isPublic?: boolean;
}

export function createRoom(
  name: string,
  operatorId: string,
  options: CreateRoomOptions = {}
): RoomState {
  const id = generateRoomId();
  const room: RoomState = {
    id,
    name,
    operatorId,
    capacity: options.capacity ?? 10,
    isPublic: options.isPublic ?? true,
    settings: { ...DEFAULT_SETTINGS },
    currentMedia: null,
    queue: [],
    playbackState: {
      status: "idle",
      currentTime: 0,
      lastUpdated: Date.now(),
    },
  };
  rooms.set(id, room);
  return room;
}

export function joinRoom(
  roomId: string,
  userId: string,
  displayName: string
): { success: boolean; room?: RoomState; error?: string } {
  const room = rooms.get(roomId);
  if (!room) {
    return { success: false, error: "Room not found" };
  }

  const currentUsers = getRoomUsers(roomId);

  if (currentUsers.length >= room.capacity) {
    return { success: false, error: "Room is full" };
  }

  const isFirstUser = currentUsers.length === 0;

  if (isFirstUser) {
    room.operatorId = userId;
  }

  const user: UserState = {
    userId,
    displayName,
    roomId,
    isOperator: isFirstUser || room.operatorId === userId,
    mediaState: {
      mediaId: null,
      downloadProgress: 0,
      isDownloaded: false,
    },
    playbackState: {
      currentTime: 0,
      isPlaying: false,
      isSynced: true,
      drift: 0,
    },
    connection: {
      status: "connected",
      lastHeartbeat: Date.now(),
    },
  };

  users.set(userId, user);
  return { success: true, room };
}

export function leaveRoom(
  roomId: string,
  userId: string
): { removedUser: UserState | null; isEmpty: boolean } {
  const user = users.get(userId);
  if (!user || user.roomId !== roomId) {
    return { removedUser: null, isEmpty: false };
  }

  users.delete(userId);

  const remaining = getRoomUsers(roomId);
  const isEmpty = remaining.length === 0;

  if (isEmpty) {
    rooms.delete(roomId);
  } else if (user.isOperator && remaining.length > 0) {
    const newOperator = remaining[0];
    newOperator.isOperator = true;
    users.set(newOperator.userId, newOperator);
    const room = rooms.get(roomId);
    if (room) {
      room.operatorId = newOperator.userId;
    }
  }

  return { removedUser: user, isEmpty };
}

export function deleteRoom(roomId: string): void {
  // Remove all users in this room
  for (const [uid, user] of users) {
    if (user.roomId === roomId) {
      users.delete(uid);
    }
  }
  rooms.delete(roomId);
}

export function getRoom(roomId: string): RoomState | null {
  return rooms.get(roomId) ?? null;
}

export function getAllPublicRooms(): RoomState[] {
  const result: RoomState[] = [];
  for (const room of rooms.values()) {
    if (room.isPublic) result.push(room);
  }
  return result;
}

export function getRoomUsers(roomId: string): UserState[] {
  const result: UserState[] = [];
  for (const user of users.values()) {
    if (user.roomId === roomId) {
      result.push(user);
    }
  }
  return result;
}

export function getUser(userId: string): UserState | null {
  return users.get(userId) ?? null;
}

export function updateUser(userId: string, updates: Partial<UserState>): UserState | null {
  const user = users.get(userId);
  if (!user) return null;
  const updated = { ...user, ...updates };
  users.set(userId, updated);
  return updated;
}

export function clearAll(): void {
  rooms.clear();
  users.clear();
}

function generateRoomId(): string {
  return Math.random().toString(36).substring(2, 8);
}
