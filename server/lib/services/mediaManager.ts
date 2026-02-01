import type { RoomState, Media } from "../types/room";

// In-memory index for media lookup by id (across all rooms)
const mediaIndex = new Map<string, Media>();

export function addMedia(room: RoomState, media: Media): Media {
  room.queue.push(media);
  mediaIndex.set(media.id, media);

  // If nothing is loaded yet, set it as current
  if (!room.currentMedia) {
    room.currentMedia = media;
    room.queue = room.queue.filter((m) => m.id !== media.id);
    room.playbackState = {
      status: "waiting",
      currentTime: 0,
      lastUpdated: Date.now(),
    };
  }

  return media;
}

export function removeMedia(room: RoomState, mediaId: string): Media[] {
  room.queue = room.queue.filter((m) => m.id !== mediaId);
  mediaIndex.delete(mediaId);
  return room.queue;
}

export function queueNext(
  room: RoomState
): { nextMedia: Media | null; updatedRoom: RoomState } {
  if (room.queue.length === 0) {
    return { nextMedia: null, updatedRoom: room };
  }

  const [nextMedia, ...rest] = room.queue;
  room.currentMedia = nextMedia;
  room.queue = rest;
  room.playbackState = {
    status: "waiting",
    currentTime: 0,
    lastUpdated: Date.now(),
  };

  return { nextMedia, updatedRoom: room };
}

export function getMediaById(mediaId: string): Media | null {
  return mediaIndex.get(mediaId) ?? null;
}

export function clearMediaIndex(): void {
  mediaIndex.clear();
}
