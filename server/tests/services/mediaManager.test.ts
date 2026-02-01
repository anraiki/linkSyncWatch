import { describe, it, expect, beforeEach } from "vitest";
import {
  addMedia,
  removeMedia,
  queueNext,
  getMediaById,
  clearMediaIndex,
} from "../../lib/services/mediaManager";
import type { RoomState, Media } from "../../lib/types/room";

beforeEach(() => {
  clearMediaIndex();
});

function makeRoom(): RoomState {
  return {
    id: "test-room",
    name: "Test",
    operatorId: "op1",
    capacity: 10,
    isPublic: true,
    settings: { waitForNewUsers: false, syncThreshold: 5, autoplayNext: true },
    currentMedia: null,
    queue: [],
    playbackState: { status: "idle", currentTime: 0, lastUpdated: Date.now() },
  };
}

function makeMedia(id: string): Media {
  return {
    id,
    filename: `${id}.mkv`,
    size: 1000,
    duration: 3600,
    source: { type: "server", path: `/uploads/${id}.mkv` },
  };
}

describe("addMedia", () => {
  it("sets first media as currentMedia automatically", () => {
    const room = makeRoom();
    const media = makeMedia("movie1");
    addMedia(room, media);
    expect(room.currentMedia).toEqual(media);
    expect(room.queue).toHaveLength(0);
    expect(room.playbackState.status).toBe("waiting");
  });

  it("queues subsequent media", () => {
    const room = makeRoom();
    addMedia(room, makeMedia("movie1"));
    addMedia(room, makeMedia("movie2"));
    expect(room.currentMedia!.id).toBe("movie1");
    expect(room.queue).toHaveLength(1);
    expect(room.queue[0].id).toBe("movie2");
  });

  it("indexes media for lookup by id", () => {
    const room = makeRoom();
    addMedia(room, makeMedia("movie1"));
    expect(getMediaById("movie1")).toBeDefined();
    expect(getMediaById("movie1")!.id).toBe("movie1");
  });
});

describe("removeMedia", () => {
  it("removes media from the queue by id", () => {
    const room = makeRoom();
    addMedia(room, makeMedia("ep1"));
    addMedia(room, makeMedia("ep2"));
    addMedia(room, makeMedia("ep3"));
    const queue = removeMedia(room, "ep2");
    expect(queue).toHaveLength(1);
    expect(queue[0].id).toBe("ep3");
  });

  it("removes from media index", () => {
    const room = makeRoom();
    addMedia(room, makeMedia("ep1"));
    addMedia(room, makeMedia("ep2"));
    removeMedia(room, "ep2");
    expect(getMediaById("ep2")).toBeNull();
  });
});

describe("queueNext", () => {
  it("pops first queue item and sets it as currentMedia", () => {
    const room = makeRoom();
    addMedia(room, makeMedia("ep1"));
    addMedia(room, makeMedia("ep2"));
    addMedia(room, makeMedia("ep3"));

    const { nextMedia } = queueNext(room);
    expect(nextMedia).toBeDefined();
    expect(nextMedia!.id).toBe("ep2");
    expect(room.currentMedia!.id).toBe("ep2");
    expect(room.queue).toHaveLength(1);
    expect(room.queue[0].id).toBe("ep3");
  });

  it("returns null when queue is empty", () => {
    const room = makeRoom();
    const { nextMedia, updatedRoom } = queueNext(room);
    expect(nextMedia).toBeNull();
    expect(updatedRoom).toBe(room);
  });
});
