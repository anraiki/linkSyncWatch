import type { Socket, Server } from "socket.io";
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from "../types/events";
import { getUser, updateUser, getRoomUsers, getRoom } from "../services/roomManager";

type TypedSocket = Socket<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;
type TypedServer = Server<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;

export function registerPlaybackHandlers(socket: TypedSocket, io: TypedServer): void {
  socket.on("user:downloadStart", (data) => {
    const userId = socket.data.userId;
    const user = getUser(userId);
    if (!user || user.roomId !== data.roomId) return;

    updateUser(userId, {
      mediaState: {
        mediaId: data.mediaId,
        downloadProgress: 0,
        isDownloaded: false,
      },
    });

    const users = getRoomUsers(data.roomId);
    io.to(data.roomId).emit("room:usersUpdate", { users });
  });

  socket.on("user:downloadProgress", (data) => {
    const userId = socket.data.userId;
    const user = getUser(userId);
    if (!user || user.roomId !== data.roomId) return;

    updateUser(userId, {
      mediaState: {
        mediaId: data.mediaId,
        downloadProgress: data.progress,
        isDownloaded: data.progress >= 100,
      },
    });

    const users = getRoomUsers(data.roomId);
    io.to(data.roomId).emit("room:usersUpdate", { users });
  });

  socket.on("user:downloadComplete", (data) => {
    const userId = socket.data.userId;
    const user = getUser(userId);
    if (!user || user.roomId !== data.roomId) return;

    updateUser(userId, {
      mediaState: {
        mediaId: data.mediaId,
        downloadProgress: 100,
        isDownloaded: true,
      },
    });

    const users = getRoomUsers(data.roomId);
    io.to(data.roomId).emit("room:usersUpdate", { users });

    // Check if all users are ready (for wait-for-downloads mode)
    checkAllReady(io, data.roomId);
  });

  socket.on("user:downloadError", (data) => {
    const userId = socket.data.userId;
    const user = getUser(userId);
    if (!user || user.roomId !== data.roomId) return;

    updateUser(userId, {
      mediaState: {
        mediaId: data.mediaId,
        downloadProgress: user.mediaState.downloadProgress,
        isDownloaded: false,
      },
    });

    const users = getRoomUsers(data.roomId);
    io.to(data.roomId).emit("room:usersUpdate", { users });
  });

  socket.on("user:playbackUpdate", (data) => {
    const userId = socket.data.userId;
    const user = getUser(userId);
    if (!user || user.roomId !== data.roomId) return;

    updateUser(userId, {
      playbackState: {
        ...user.playbackState,
        currentTime: data.currentTime,
      },
    });
  });
}

function checkAllReady(io: TypedServer, roomId: string): void {
  const room = getRoom(roomId);
  if (!room) return;

  const users = getRoomUsers(roomId);
  const allReady = users.every((u) => u.mediaState.isDownloaded);

  if (allReady && room.playbackState.status === "waiting") {
    io.to(roomId).emit("room:allReady");
  }
}
