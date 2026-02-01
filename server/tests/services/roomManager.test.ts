import { describe, it, expect, beforeEach } from "vitest";
import {
  createRoom,
  joinRoom,
  leaveRoom,
  getRoom,
  getRoomUsers,
  getAllPublicRooms,
  deleteRoom,
  clearAll,
} from "../../lib/services/roomManager";

beforeEach(() => {
  clearAll();
});

describe("createRoom", () => {
  it("returns a valid RoomState with defaults", () => {
    const room = createRoom("Test Room", "user1");
    expect(room.name).toBe("Test Room");
    expect(room.operatorId).toBe("user1");
    expect(room.id).toBeTruthy();
    expect(room.playbackState.status).toBe("idle");
    expect(room.currentMedia).toBeNull();
    expect(room.queue).toEqual([]);
    expect(room.capacity).toBe(10);
    expect(room.isPublic).toBe(true);
  });

  it("respects capacity and isPublic options", () => {
    const room = createRoom("Private", "user1", { capacity: 5, isPublic: false });
    expect(room.capacity).toBe(5);
    expect(room.isPublic).toBe(false);
  });
});

describe("joinRoom", () => {
  it("succeeds when room exists", () => {
    const room = createRoom("Test Room", "user1");
    const result = joinRoom(room.id, "user2", "Alice");
    expect(result.success).toBe(true);
    expect(result.room).toBeDefined();
  });

  it("user appears in room users after joining", () => {
    const room = createRoom("Test Room", "user1");
    joinRoom(room.id, "user2", "Alice");
    const users = getRoomUsers(room.id);
    expect(users).toHaveLength(1);
    expect(users[0].userId).toBe("user2");
    expect(users[0].displayName).toBe("Alice");
  });

  it("returns error for non-existent room", () => {
    const result = joinRoom("nonexistent", "user1", "Bob");
    expect(result.success).toBe(false);
    expect(result.error).toBe("Room not found");
  });

  it("first joiner becomes operator", () => {
    const room = createRoom("Test Room", "someone_else");
    joinRoom(room.id, "user1", "First");
    const users = getRoomUsers(room.id);
    expect(users[0].isOperator).toBe(true);
    expect(room.operatorId).toBe("user1");
  });

  it("rejects join when room is full", () => {
    const room = createRoom("Small Room", "user1", { capacity: 2 });
    joinRoom(room.id, "user1", "A");
    joinRoom(room.id, "user2", "B");
    const result = joinRoom(room.id, "user3", "C");
    expect(result.success).toBe(false);
    expect(result.error).toBe("Room is full");
  });
});

describe("leaveRoom", () => {
  it("removes user from room", () => {
    const room = createRoom("Test Room", "user1");
    joinRoom(room.id, "user1", "Host");
    joinRoom(room.id, "user2", "Guest");

    const { removedUser } = leaveRoom(room.id, "user2");
    expect(removedUser).toBeDefined();
    expect(removedUser!.userId).toBe("user2");

    const users = getRoomUsers(room.id);
    expect(users).toHaveLength(1);
  });

  it("reports room is empty when last user leaves", () => {
    const room = createRoom("Test Room", "user1");
    joinRoom(room.id, "user1", "Solo");

    const { isEmpty } = leaveRoom(room.id, "user1");
    expect(isEmpty).toBe(true);
    expect(getRoom(room.id)).toBeNull();
  });

  it("transfers operator when operator leaves", () => {
    const room = createRoom("Test Room", "user1");
    joinRoom(room.id, "user1", "Host");
    joinRoom(room.id, "user2", "Guest");

    leaveRoom(room.id, "user1");
    const users = getRoomUsers(room.id);
    expect(users).toHaveLength(1);
    expect(users[0].isOperator).toBe(true);
    expect(users[0].userId).toBe("user2");
  });
});

describe("getAllPublicRooms", () => {
  it("returns only public rooms", () => {
    createRoom("Public", "u1", { isPublic: true });
    createRoom("Private", "u2", { isPublic: false });
    const rooms = getAllPublicRooms();
    expect(rooms).toHaveLength(1);
    expect(rooms[0].name).toBe("Public");
  });
});

describe("deleteRoom", () => {
  it("removes the room and all its users", () => {
    const room = createRoom("To Delete", "u1");
    joinRoom(room.id, "u1", "Host");
    joinRoom(room.id, "u2", "Guest");

    deleteRoom(room.id);
    expect(getRoom(room.id)).toBeNull();
    expect(getRoomUsers(room.id)).toHaveLength(0);
  });
});
