import { describe, it, expect, beforeEach } from "vitest";
import {
  calcDrift,
  isUserSynced,
  getUsersToResync,
} from "../../lib/services/syncEngine";
import {
  createRoom,
  joinRoom,
  getRoomUsers,
  updateUser,
  clearAll,
} from "../../lib/services/roomManager";

beforeEach(() => {
  clearAll();
});

describe("calcDrift", () => {
  it("returns correct positive delta when user is ahead", () => {
    expect(calcDrift(105, 100)).toBe(5);
  });

  it("returns correct negative delta when user is behind", () => {
    expect(calcDrift(95, 100)).toBe(-5);
  });

  it("returns 0 when times match", () => {
    expect(calcDrift(100, 100)).toBe(0);
  });
});

describe("isUserSynced", () => {
  it("returns true when drift is within threshold", () => {
    expect(isUserSynced(3, 5)).toBe(true);
    expect(isUserSynced(-3, 5)).toBe(true);
  });

  it("returns false when drift exceeds threshold", () => {
    expect(isUserSynced(6, 5)).toBe(false);
    expect(isUserSynced(-6, 5)).toBe(false);
  });

  it("returns true when drift equals threshold", () => {
    expect(isUserSynced(5, 5)).toBe(true);
  });
});

describe("getUsersToResync", () => {
  it("returns only users that exceed drift threshold", () => {
    const room = createRoom("Test", "op1");
    joinRoom(room.id, "op1", "Operator");
    joinRoom(room.id, "u1", "Synced");
    joinRoom(room.id, "u2", "Drifted");

    updateUser("op1", {
      playbackState: { currentTime: 100, isPlaying: true, isSynced: true, drift: 0 },
    });
    updateUser("u1", {
      playbackState: { currentTime: 102, isPlaying: true, isSynced: true, drift: 2 },
    });
    updateUser("u2", {
      playbackState: { currentTime: 110, isPlaying: true, isSynced: false, drift: 10 },
    });

    const users = getRoomUsers(room.id);
    const toResync = getUsersToResync(room, users);

    expect(toResync).toHaveLength(1);
    expect(toResync[0].userId).toBe("u2");
  });

  it("does not include the operator", () => {
    const room = createRoom("Test", "op1");
    joinRoom(room.id, "op1", "Operator");

    updateUser("op1", {
      playbackState: { currentTime: 100, isPlaying: true, isSynced: true, drift: 0 },
    });

    const users = getRoomUsers(room.id);
    const toResync = getUsersToResync(room, users);
    expect(toResync).toHaveLength(0);
  });
});
