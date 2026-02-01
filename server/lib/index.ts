import Fastify from "fastify";
import fastifyJwt from "@fastify/jwt";
import fastifyMultipart from "@fastify/multipart";
import { Server } from "socket.io";
import { initDb } from "./db";
import { authRoutes } from "./auth";
import { roomRoutes } from "./routes/rooms";
import { mediaRoutes } from "./routes/media";
import { registerRoomHandlers } from "./handlers/roomHandlers";
import { registerPlaybackHandlers } from "./handlers/playbackHandlers";
import { registerOperatorHandlers } from "./handlers/operatorHandlers";
import { registerChatHandlers } from "./handlers/chatHandlers";
import type { ServerToClientEvents, ClientToServerEvents, SocketData } from "./types/events";

const PORT = Number(process.env.PORT) || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "dsync-dev-secret";

async function main() {
  initDb();

  const app = Fastify({ logger: true });

  await app.register(fastifyJwt, { secret: JWT_SECRET });
  await app.register(fastifyMultipart, { limits: { fileSize: 10 * 1024 * 1024 * 1024 } }); // 10 GB

  // REST routes
  await app.register(authRoutes);
  await app.register(roomRoutes);
  await app.register(mediaRoutes);

  await app.listen({ port: PORT, host: "0.0.0.0" });

  // Socket.IO on the same HTTP server
  const io = new Server<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>(
    app.server,
    { cors: { origin: "*" } }
  );

  // JWT auth middleware for sockets
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) {
      return next(new Error("Authentication required"));
    }

    try {
      const decoded = app.jwt.verify<{ userId: string; displayName: string; guest?: boolean }>(token);
      socket.data.userId = decoded.userId;
      socket.data.displayName = decoded.displayName;
      socket.data.guest = decoded.guest ?? false;
      next();
    } catch {
      next(new Error("Invalid token"));
    }
  });

  io.on("connection", (socket) => {
    app.log.info(`User connected: ${socket.data.userId} (${socket.data.displayName})`);
    registerRoomHandlers(socket, io);
    registerPlaybackHandlers(socket, io);
    registerOperatorHandlers(socket, io);
    registerChatHandlers(socket, io);
  });

  app.log.info(`dSync server running on port ${PORT}`);
}

main().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});
