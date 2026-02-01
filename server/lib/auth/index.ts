import { FastifyInstance } from "fastify";
import { z } from "zod";
import crypto from "crypto";
import bcrypt from "bcrypt";
import { getDb } from "../db";

const SALT_ROUNDS = 10;

const ALLOW_REGISTRATION = (process.env.ALLOW_REGISTRATION ?? "false") === "true";
const ALLOW_GUESTS = (process.env.ALLOW_GUESTS ?? "true") === "true";
const SERVER_NAME = process.env.SERVER_NAME || "dSync Server";

export { ALLOW_REGISTRATION, ALLOW_GUESTS, SERVER_NAME };

const registerSchema = z.object({
  username: z.string().min(3).max(32),
  password: z.string().min(6).max(128),
  displayName: z.string().min(1).max(64),
});

const loginSchema = z.object({
  username: z.string(),
  password: z.string(),
});

const guestSchema = z.object({
  displayName: z.string().min(1).max(64),
});

export async function authRoutes(app: FastifyInstance) {
  app.post("/auth/register", async (request, reply) => {
    if (!ALLOW_REGISTRATION) {
      return reply.status(403).send({ error: "Registration is disabled" });
    }

    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten().fieldErrors });
    }

    const { password, displayName } = parsed.data;
    const username = parsed.data.username.toLowerCase();
    const db = getDb();

    const existing = db
      .prepare("SELECT id FROM users WHERE username = ?")
      .get(username) as { id: number } | undefined;

    if (existing) {
      return reply.status(409).send({ error: "Username already taken" });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const result = db
      .prepare(
        "INSERT INTO users (username, password_hash, display_name) VALUES (?, ?, ?)"
      )
      .run(username, passwordHash, displayName);

    const token = app.jwt.sign({
      userId: result.lastInsertRowid.toString(),
      displayName,
    });

    return reply.status(201).send({ token });
  });

  app.post("/auth/login", async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten().fieldErrors });
    }

    const { password } = parsed.data;
    const username = parsed.data.username.toLowerCase();
    const db = getDb();

    const user = db
      .prepare("SELECT id, password_hash, display_name FROM users WHERE username = ?")
      .get(username) as
      | { id: number; password_hash: string; display_name: string }
      | undefined;

    if (!user) {
      return reply.status(401).send({ error: "Invalid credentials" });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return reply.status(401).send({ error: "Invalid credentials" });
    }

    const token = app.jwt.sign({
      userId: user.id.toString(),
      displayName: user.display_name,
    });

    return reply.send({ token });
  });

  app.post("/auth/guest", async (request, reply) => {
    if (!ALLOW_GUESTS) {
      return reply.status(403).send({ error: "Guest access is disabled" });
    }

    const parsed = guestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten().fieldErrors });
    }

    const { displayName } = parsed.data;
    const userId = "guest-" + crypto.randomBytes(16).toString("hex");

    const token = app.jwt.sign({
      userId,
      displayName,
      guest: true,
    });

    return reply.send({ token });
  });
}
