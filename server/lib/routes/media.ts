import { FastifyInstance } from "fastify";
import { z } from "zod";
import fs from "fs";
import path from "path";
import crypto from "crypto";
import { getRoom } from "../services/roomManager";
import { addMedia, removeMedia, getMediaById } from "../services/mediaManager";

const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, "../../uploads");

const addUrlSchema = z.object({
  url: z.string().url(),
  filename: z.string().min(1).max(255),
});

export async function mediaRoutes(app: FastifyInstance) {
  // Ensure upload directory exists
  if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  }

  // Upload a file to the server
  app.post("/api/rooms/:roomId/media/upload", async (request, reply) => {
    const { roomId } = request.params as { roomId: string };

    let userId: string;
    try {
      const decoded = await request.jwtVerify<{ userId: string }>();
      userId = decoded.userId;
    } catch {
      return reply.status(401).send({ error: "Authentication required" });
    }

    const room = getRoom(roomId);
    if (!room) return reply.status(404).send({ error: "Room not found" });
    if (room.operatorId !== userId) {
      return reply.status(403).send({ error: "Only the operator can upload media" });
    }

    const data = await request.file();
    if (!data) {
      return reply.status(400).send({ error: "No file provided" });
    }

    const mediaId = crypto.randomUUID();
    const ext = path.extname(data.filename) || "";
    const storedName = `${mediaId}${ext}`;
    const filePath = path.join(UPLOAD_DIR, storedName);

    // Stream file to disk
    const writeStream = fs.createWriteStream(filePath);
    await new Promise<void>((resolve, reject) => {
      data.file.pipe(writeStream);
      data.file.on("error", reject);
      writeStream.on("finish", resolve);
      writeStream.on("error", reject);
    });

    const stat = fs.statSync(filePath);

    const media = addMedia(room, {
      id: mediaId,
      filename: data.filename,
      size: stat.size,
      duration: 0,
      source: { type: "server", path: filePath },
    });

    return reply.status(201).send({ media });
  });

  // Add an external URL as media source
  app.post("/api/rooms/:roomId/media/url", async (request, reply) => {
    const { roomId } = request.params as { roomId: string };

    let userId: string;
    try {
      const decoded = await request.jwtVerify<{ userId: string }>();
      userId = decoded.userId;
    } catch {
      return reply.status(401).send({ error: "Authentication required" });
    }

    const room = getRoom(roomId);
    if (!room) return reply.status(404).send({ error: "Room not found" });
    if (room.operatorId !== userId) {
      return reply.status(403).send({ error: "Only the operator can add media" });
    }

    const parsed = addUrlSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten().fieldErrors });
    }

    const mediaId = crypto.randomUUID();
    const media = addMedia(room, {
      id: mediaId,
      filename: parsed.data.filename,
      size: 0,
      duration: 0,
      source: { type: "external", url: parsed.data.url },
    });

    return reply.status(201).send({ media });
  });

  // Remove media from room queue
  app.delete("/api/rooms/:roomId/media/:mediaId", async (request, reply) => {
    const { roomId, mediaId } = request.params as { roomId: string; mediaId: string };

    let userId: string;
    try {
      const decoded = await request.jwtVerify<{ userId: string }>();
      userId = decoded.userId;
    } catch {
      return reply.status(401).send({ error: "Authentication required" });
    }

    const room = getRoom(roomId);
    if (!room) return reply.status(404).send({ error: "Room not found" });
    if (room.operatorId !== userId) {
      return reply.status(403).send({ error: "Only the operator can remove media" });
    }

    removeMedia(room, mediaId);
    return reply.status(204).send();
  });

  // Download a server-hosted file (with range support)
  app.get("/api/media/:id/download", async (request, reply) => {
    const { id } = request.params as { id: string };

    const media = getMediaById(id);
    if (!media) {
      return reply.status(404).send({ error: "Media not found" });
    }
    if (media.source.type !== "server" || !media.source.path) {
      return reply.status(400).send({ error: "Not a server-hosted file" });
    }

    const filePath = media.source.path;
    if (!fs.existsSync(filePath)) {
      return reply.status(404).send({ error: "File not found on disk" });
    }

    const stat = fs.statSync(filePath);
    const fileSize = stat.size;
    const range = request.headers.range;

    if (range) {
      const parts = range.replace(/bytes=/, "").split("-");
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
      const chunkSize = end - start + 1;

      reply.raw.writeHead(206, {
        "Content-Range": `bytes ${start}-${end}/${fileSize}`,
        "Accept-Ranges": "bytes",
        "Content-Length": chunkSize,
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${media.filename}"`,
      });

      fs.createReadStream(filePath, { start, end }).pipe(reply.raw);
    } else {
      reply.raw.writeHead(200, {
        "Content-Length": fileSize,
        "Content-Type": "application/octet-stream",
        "Accept-Ranges": "bytes",
        "Content-Disposition": `attachment; filename="${media.filename}"`,
      });

      fs.createReadStream(filePath).pipe(reply.raw);
    }

    return reply;
  });
}
