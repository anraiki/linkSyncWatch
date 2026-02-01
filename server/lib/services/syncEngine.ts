import type { Server } from "socket.io";
import type { RoomState } from "../types/room";
import type { UserState } from "../types/user";
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from "../types/events";
import { getRoom, getRoomUsers } from "./roomManager";

type TypedServer = Server<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;

const syncIntervals = new Map<string, ReturnType<typeof setInterval>>();

const SYNC_INTERVAL_MS = 3000;

export function calcDrift(userTime: number, operatorTime: number): number {
  return userTime - operatorTime;
}

export function isUserSynced(drift: number, threshold: number): boolean {
  return Math.abs(drift) <= threshold;
}

export function getUsersToResync(room: RoomState, users: UserState[]): UserState[] {
  return users.filter(
    (u) =>
      !u.isOperator &&
      !isUserSynced(u.playbackState.drift, room.settings.syncThreshold)
  );
}

export function estimateOperatorTime(room: RoomState, operator: UserState): number {
  if (room.playbackState.status !== "playing") {
    return operator.playbackState.currentTime;
  }
  const elapsed = (Date.now() - room.playbackState.lastUpdated) / 1000;
  return room.playbackState.currentTime + elapsed;
}

export function startSyncLoop(io: TypedServer, roomId: string): void {
  if (syncIntervals.has(roomId)) return;

  const interval = setInterval(() => {
    const room = getRoom(roomId);
    if (!room || room.playbackState.status !== "playing") return;

    const users = getRoomUsers(roomId);
    const operator = users.find((u) => u.isOperator);
    if (!operator) return;

    const estimatedOpTime = estimateOperatorTime(room, operator);

    for (const user of users) {
      if (user.isOperator) continue;

      const drift = calcDrift(user.playbackState.currentTime, estimatedOpTime);
      user.playbackState.drift = drift;
      user.playbackState.isSynced = isUserSynced(drift, room.settings.syncThreshold);

      if (!user.playbackState.isSynced) {
        io.to(user.userId).emit("sync:forceResync", { toTime: estimatedOpTime });
      }
    }

    // Send sync check to all non-operator users
    for (const user of users) {
      if (user.isOperator) continue;
      io.to(user.userId).emit("sync:check", {
        operatorTime: estimatedOpTime,
        timestamp: Date.now(),
      });
    }
  }, SYNC_INTERVAL_MS);

  syncIntervals.set(roomId, interval);
}

export function stopSyncLoop(roomId: string): void {
  const interval = syncIntervals.get(roomId);
  if (interval) {
    clearInterval(interval);
    syncIntervals.delete(roomId);
  }
}
