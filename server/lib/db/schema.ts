export const CREATE_USERS_TABLE = `
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
  )
`;

export const CREATE_ROOMS_TABLE = `
  CREATE TABLE IF NOT EXISTS rooms (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    operator_id TEXT NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 10,
    is_public INTEGER NOT NULL DEFAULT 1,
    settings TEXT NOT NULL DEFAULT '{}',
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
  )
`;

export const CREATE_MESSAGES_TABLE = `
  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    content TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'user',
    timestamp INTEGER NOT NULL
  )
`;

export const CREATE_MESSAGES_INDEX = `
  CREATE INDEX IF NOT EXISTS idx_messages_room_ts ON messages(room_id, timestamp)
`;

export const CREATE_MEDIA_TABLE = `
  CREATE TABLE IF NOT EXISTS media (
    id TEXT PRIMARY KEY,
    room_id TEXT,
    filename TEXT NOT NULL,
    size INTEGER NOT NULL DEFAULT 0,
    duration REAL NOT NULL DEFAULT 0,
    source_type TEXT NOT NULL,
    source_path TEXT,
    queue_order INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
  )
`;
