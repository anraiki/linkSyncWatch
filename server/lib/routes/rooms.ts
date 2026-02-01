import { FastifyInstance } from "fastify";
import { z } from "zod";
import { getRoom, getRoomUsers, createRoom, getAllPublicRooms, deleteRoom } from "../services/roomManager";
import { ALLOW_REGISTRATION, ALLOW_GUESTS, SERVER_NAME } from "../auth";
import type { RoomSummary } from "../types/room";

const createRoomSchema = z.object({
  name: z.string().min(1).max(100),
  capacity: z.number().int().min(1).max(100).optional().default(10),
  isPublic: z.boolean().optional().default(true),
});

export async function roomRoutes(app: FastifyInstance) {
  // Server capabilities
  app.get("/api/server/info", async () => {
    return {
      name: SERVER_NAME,
      registrationEnabled: ALLOW_REGISTRATION,
      guestEnabled: ALLOW_GUESTS,
    };
  });

  // List all public rooms
  app.get("/api/rooms", async () => {
    const rooms = getAllPublicRooms();
    const summaries: RoomSummary[] = rooms.map((room) => {
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
    });
    return { rooms: summaries };
  });

  // Create a room
  app.post("/api/rooms", async (request, reply) => {
    const parsed = createRoomSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten().fieldErrors });
    }

    // Extract userId from JWT
    let operatorId = "anonymous";
    let isGuest = false;
    try {
      const decoded = await request.jwtVerify<{ userId: string; guest?: boolean }>();
      operatorId = decoded.userId;
      isGuest = decoded.guest ?? false;
    } catch {
      // No auth required to create rooms, but operator will be anonymous
    }

    if (isGuest) {
      return reply.status(403).send({ error: "Guests cannot create rooms" });
    }

    const room = createRoom(parsed.data.name, operatorId, {
      capacity: parsed.data.capacity,
      isPublic: parsed.data.isPublic,
    });

    return reply.status(201).send({ room });
  });

  // Get room details
  app.get("/api/rooms/:id", async (request, reply) => {
    const { id } = request.params as { id: string };
    const room = getRoom(id);
    if (!room) {
      return reply.status(404).send({ error: "Room not found" });
    }
    const users = getRoomUsers(id);
    return { ...room, users };
  });

  // Delete room (operator only)
  app.delete("/api/rooms/:id", async (request, reply) => {
    const { id } = request.params as { id: string };

    let userId: string;
    try {
      const decoded = await request.jwtVerify<{ userId: string }>();
      userId = decoded.userId;
    } catch {
      return reply.status(401).send({ error: "Authentication required" });
    }

    const room = getRoom(id);
    if (!room) {
      return reply.status(404).send({ error: "Room not found" });
    }
    if (room.operatorId !== userId) {
      return reply.status(403).send({ error: "Only the operator can delete the room" });
    }

    deleteRoom(id);
    return reply.status(204).send();
  });
}
