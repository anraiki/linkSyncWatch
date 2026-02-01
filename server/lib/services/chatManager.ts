import crypto from "crypto";
import { getDb } from "../db";
import type { ChatMessage } from "../types/room";

export function saveMessage(msg: ChatMessage): void {
  const db = getDb();
  db.prepare(
    `INSERT INTO messages (id, room_id, user_id, display_name, content, type, timestamp)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(msg.id, msg.roomId, msg.userId, msg.displayName, msg.content, msg.type, msg.timestamp);
}

export function getHistory(
  roomId: string,
  opts: { before?: number; limit?: number; type?: "user" | "system" } = {}
): ChatMessage[] {
  const db = getDb();
  const limit = Math.min(Math.max(opts.limit ?? 50, 1), 200);

  const conditions: string[] = ["room_id = ?"];
  const params: (string | number)[] = [roomId];

  if (opts.before != null) {
    conditions.push("timestamp < ?");
    params.push(opts.before);
  }

  if (opts.type != null) {
    conditions.push("type = ?");
    params.push(opts.type);
  }

  const where = conditions.join(" AND ");
  const rows = db
    .prepare(
      `SELECT id, room_id, user_id, display_name, content, type, timestamp
       FROM messages
       WHERE ${where}
       ORDER BY timestamp DESC
       LIMIT ?`
    )
    .all(...params, limit) as Array<{
      id: string;
      room_id: string;
      user_id: string;
      display_name: string;
      content: string;
      type: "user" | "system";
      timestamp: number;
    }>;

  return rows.map((r) => ({
    id: r.id,
    roomId: r.room_id,
    userId: r.user_id,
    displayName: r.display_name,
    content: r.content,
    type: r.type,
    timestamp: r.timestamp,
  }));
}

export function createSystemMessage(roomId: string, content: string): ChatMessage {
  return {
    id: crypto.randomUUID(),
    roomId,
    userId: "system",
    displayName: "System",
    content,
    type: "system",
    timestamp: Date.now(),
  };
}
