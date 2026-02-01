import Database from "better-sqlite3";
import path from "path";
import fs from "fs";
import { CREATE_USERS_TABLE, CREATE_ROOMS_TABLE, CREATE_MEDIA_TABLE, CREATE_MESSAGES_TABLE, CREATE_MESSAGES_INDEX } from "./schema";

const DB_PATH = process.env.DB_PATH || path.join(__dirname, "../../data/dsync.db");

let db: Database.Database;

export function getDb(): Database.Database {
  if (!db) {
    db = initDb(DB_PATH);
  }
  return db;
}

export function initDb(dbPath: string = DB_PATH): Database.Database {
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  db = new Database(dbPath);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");

  db.exec(CREATE_USERS_TABLE);
  db.exec(CREATE_ROOMS_TABLE);
  db.exec(CREATE_MEDIA_TABLE);
  db.exec(CREATE_MESSAGES_TABLE);
  db.exec(CREATE_MESSAGES_INDEX);

  return db;
}
