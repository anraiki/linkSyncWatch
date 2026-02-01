import type { Socket, Server } from "socket.io";
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from "../types/events";
import type { RoomSummary } from "../types/room";
import {
  joinRoom,
  leaveRoom,
  getRoom,
  getRoomUsers,
  createRoom,
  getAllPublicRooms,
} from "../services/roomManager";
import { startSyncLoop, stopSyncLoop } from "../services/syncEngine";
import { createSystemMessage, saveMessage } from "../services/chatManager";

type TypedSocket = Socket<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;
type TypedServer = Server<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;

export function registerRoomHandlers(socket: TypedSocket, io: TypedServer): void {
  socket.on("room:join", (data, callback) => {
    const { roomId, displayName } = data;
    const userId = socket.data.userId;

    // Create room if it doesn't exist (guests cannot auto-create)
    let room = getRoom(roomId);
    if (!room) {
      if (socket.data.guest) {
        callback?.({ success: false, error: "Guests can only join existing rooms" });
        return;
      }
      room = createRoom(roomId, userId);
    }

    const result = joinRoom(roomId, userId, displayName);

    if (!result.success) {
      callback?.({ success: false, error: result.error });
      return;
    }

    socket.join(roomId);
    socket.join(userId);

    const users = getRoomUsers(roomId);
    socket.emit("room:state", { ...result.room!, users });

    const joiner = users.find((u) => u.userId === userId);
    if (joiner) {
      socket.to(roomId).emit("room:userJoined", joiner);
    }

    const joinMsg = createSystemMessage(roomId, `${displayName} joined the room`);
    saveMessage(joinMsg);
    io.to(roomId).emit("chat:message", joinMsg);

    // Wait-for-downloads: pause if setting is on and room was playing
    if (
      result.room!.settings.waitForNewUsers &&
      result.room!.playbackState.status === "playing"
    ) {
      result.room!.playbackState.status = "waiting";
      result.room!.playbackState.lastUpdated = Date.now();
      io.to(roomId).emit("playback:pause", {
        atTime: result.room!.playbackState.currentTime,
        reason: "waiting_for_user",
      });
    }

    startSyncLoop(io, roomId);
    broadcastLobbyUpdate(io);
    callback?.({ success: true });
  });

  socket.on("room:leave", (data) => {
    handleLeave(socket, io, data.roomId);
  });

  socket.on("disconnect", () => {
    const userId = socket.data.userId;
    for (const roomId of socket.rooms) {
      if (roomId === socket.id || roomId === userId) continue;
      handleLeave(socket, io, roomId);
    }
  });

  // Lobby subscription
  socket.on("lobby:subscribe", () => {
    socket.join("lobby");
    const rooms = getAllPublicRooms();
    const summaries = rooms.map(buildRoomSummary);
    socket.emit("lobby:update", { rooms: summaries });
  });
}

function handleLeave(socket: TypedSocket, io: TypedServer, roomId: string): void {
  const userId = socket.data.userId;
  const { removedUser, isEmpty } = leaveRoom(roomId, userId);

  if (!removedUser) return;

  socket.leave(roomId);
  socket.to(roomId).emit("room:userLeft", { userId });

  const leaveMsg = createSystemMessage(roomId, `${removedUser.displayName} left the room`);
  saveMessage(leaveMsg);
  io.to(roomId).emit("chat:message", leaveMsg);

  if (isEmpty) {
    stopSyncLoop(roomId);
  } else {
    if (removedUser.isOperator) {
      const room = getRoom(roomId);
      if (room) {
        const newOp = getRoomUsers(roomId).find((u) => u.userId === room.operatorId);
        if (newOp) {
          const opMsg = createSystemMessage(roomId, `${newOp.displayName} is now the operator`);
          saveMessage(opMsg);
          io.to(roomId).emit("chat:message", opMsg);
        }
      }
    }
    const users = getRoomUsers(roomId);
    io.to(roomId).emit("room:usersUpdate", { users });
  }

  broadcastLobbyUpdate(io);
}

function buildRoomSummary(room: ReturnType<typeof getRoom> & {}): RoomSummary {
  const users = getRoomUsers(room.id);
  return {
    id: room.id,
    name: room.name,
    userCount: users.length,
    capacity: room.capacity,
    currentMedia: room.currentMedia
      ? { filename: room.currentMedia.filename, duration: room.currentMedia.duration }
      : null,
    status: room.playbackState.status,
    currentTime: room.playbackState.currentTime || undefined,
  };
}

function broadcastLobbyUpdate(io: TypedServer): void {
  const rooms = getAllPublicRooms();
  const summaries = rooms.map(buildRoomSummary);
  io.to("lobby").emit("lobby:update", { rooms: summaries });
}
