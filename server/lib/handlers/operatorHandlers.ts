import type { Socket, Server } from "socket.io";
import crypto from "crypto";
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from "../types/events";
import { getRoom } from "../services/roomManager";
import { addMedia, removeMedia, queueNext } from "../services/mediaManager";

type TypedSocket = Socket<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;
type TypedServer = Server<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;

function isOperator(userId: string, roomId: string): boolean {
  const room = getRoom(roomId);
  return room?.operatorId === userId;
}

export function registerOperatorHandlers(socket: TypedSocket, io: TypedServer): void {
  socket.on("op:play", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    const atTime = data.atTime ?? room.playbackState.currentTime;
    room.playbackState = {
      status: "playing",
      currentTime: atTime,
      lastUpdated: Date.now(),
    };

    io.to(data.roomId).emit("playback:play", { atTime });
  });

  socket.on("op:pause", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    room.playbackState.status = "paused";
    room.playbackState.lastUpdated = Date.now();

    io.to(data.roomId).emit("playback:pause", {
      atTime: room.playbackState.currentTime,
    });
  });

  socket.on("op:seek", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    room.playbackState.currentTime = data.toTime;
    room.playbackState.lastUpdated = Date.now();

    io.to(data.roomId).emit("playback:seek", { toTime: data.toTime });
  });

  socket.on("op:stop", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    room.playbackState = {
      status: "idle",
      currentTime: 0,
      lastUpdated: Date.now(),
    };

    io.to(data.roomId).emit("playback:stop");
  });

  socket.on("op:addMediaUrl", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    const media = addMedia(room, {
      id: crypto.randomUUID(),
      filename: data.filename,
      size: 0,
      duration: 0,
      source: { type: "external", url: data.url },
    });

    io.to(data.roomId).emit("media:added", { media });

    // If this became currentMedia (first item), also emit media:changed
    if (room.currentMedia?.id === media.id) {
      io.to(data.roomId).emit("media:changed", { currentMedia: media });
    }

    io.to(data.roomId).emit("queue:updated", { queue: room.queue });
  });

  socket.on("op:removeMedia", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    const queue = removeMedia(room, data.mediaId);

    io.to(data.roomId).emit("media:removed", { mediaId: data.mediaId });
    io.to(data.roomId).emit("queue:updated", { queue });
  });

  socket.on("op:queueNext", (data) => {
    const userId = socket.data.userId;
    if (!isOperator(userId, data.roomId)) return;

    const room = getRoom(data.roomId);
    if (!room) return;

    const { nextMedia } = queueNext(room);

    if (nextMedia) {
      io.to(data.roomId).emit("media:changed", { currentMedia: nextMedia });
    }
    io.to(data.roomId).emit("queue:updated", { queue: room.queue });
  });
}
