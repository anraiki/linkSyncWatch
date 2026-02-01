import crypto from "crypto";
import type { Socket, Server } from "socket.io";
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from "../types/events";
import { saveMessage, getHistory } from "../services/chatManager";

type TypedSocket = Socket<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;
type TypedServer = Server<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>;

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function registerChatHandlers(socket: TypedSocket, io: TypedServer): void {
  socket.on("chat:send", (data) => {
    const { roomId, content } = data;

    if (!socket.rooms.has(roomId)) return;

    if (!content || typeof content !== "string" || content.length < 1 || content.length > 1000) {
      return;
    }

    const msg = {
      id: crypto.randomUUID(),
      roomId,
      userId: socket.data.userId,
      displayName: socket.data.displayName,
      content: escapeHtml(content),
      type: "user" as const,
      timestamp: Date.now(),
    };

    saveMessage(msg);
    io.to(roomId).emit("chat:message", msg);
  });

  socket.on("chat:history", (data, callback) => {
    const { roomId, before, limit, type } = data;

    if (!socket.rooms.has(roomId)) {
      callback({ messages: [] });
      return;
    }

    const messages = getHistory(roomId, { before, limit, type });
    callback({ messages });
  });
}
