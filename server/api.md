# dSync Server API Reference

## Server Info (REST)

### GET /api/server/info

Returns server capabilities. No auth required. Clients should call this first to determine which auth methods are available.

**Response (200):**
```json
{
  "name": "dSync Server",
  "registrationEnabled": false,
  "guestEnabled": true
}
```

- `name` — display name for the server
- `registrationEnabled` — whether `POST /auth/register` is available
- `guestEnabled` — whether `POST /auth/guest` is available

---

## Authentication (REST)

All Socket.IO connections require a JWT token. Obtain one via the REST auth endpoints.

### POST /auth/register

Create a new user account. Disabled when `ALLOW_REGISTRATION` is `false` (the default).

**Request body:**
```json
{
  "username": "string (3–32 chars)",
  "password": "string (6–128 chars)",
  "displayName": "string (1–64 chars)"
}
```

**Success (201):**
```json
{ "token": "<jwt>" }
```

**Errors:**
- `400` — validation failed (field errors object)
- `403` — `{ "error": "Registration is disabled" }`
- `409` — `{ "error": "Username already taken" }`

### POST /auth/login

Authenticate an existing user.

**Request body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Success (200):**
```json
{ "token": "<jwt>" }
```

**Errors:**
- `400` — validation failed
- `401` — `{ "error": "Invalid credentials" }`

### POST /auth/guest

Create a temporary guest session. Disabled when `ALLOW_GUESTS` is `false`.

**Request body:**
```json
{
  "displayName": "string (1–64 chars)"
}
```

**Success (200):**
```json
{ "token": "<jwt>" }
```

**Errors:**
- `400` — validation failed
- `403` — `{ "error": "Guest access is disabled" }`

### JWT Payload

```json
{
  "userId": "string",
  "displayName": "string",
  "guest": true
}
```

The `guest` field is only present (and `true`) for tokens issued by `/auth/guest`. Tokens from `/auth/login` and `/auth/register` omit it.

---

## Room Lobby (REST)

### GET /api/rooms

List all public rooms. No auth required.

**Response:**
```json
{
  "rooms": [RoomSummary]
}
```

### POST /api/rooms

Create a new room. Auth optional (operator will be "anonymous" if no JWT). **Guests cannot create rooms.**

**Request body:**
```json
{
  "name": "string (1–100 chars)",
  "capacity": 10,
  "isPublic": true
}
```
`capacity` and `isPublic` are optional with defaults shown.

**Success (201):**
```json
{ "room": RoomState }
```

**Errors:**
- `400` — validation failed
- `403` — `{ "error": "Guests cannot create rooms" }`

### GET /api/rooms/:id

Get full room details including current users. No auth required.

**Success (200):**
```json
RoomState & { "users": [UserState] }
```

**Errors:**
- `404` — `{ "error": "Room not found" }`

### DELETE /api/rooms/:id

Delete a room. Requires JWT. Only the room operator can delete.

**Success:** `204 No Content`

**Errors:**
- `401` — not authenticated
- `403` — not the operator
- `404` — room not found

---

## Media Management (REST)

### POST /api/rooms/:roomId/media/upload

Upload a file to the server. Requires JWT. Operator only. Uses `multipart/form-data`.

**Success (201):**
```json
{ "media": Media }
```

### POST /api/rooms/:roomId/media/url

Add an external URL as a media source. Requires JWT. Operator only.

**Request body:**
```json
{
  "url": "https://...",
  "filename": "Movie.mkv"
}
```

**Success (201):**
```json
{ "media": Media }
```

### DELETE /api/rooms/:roomId/media/:mediaId

Remove media from the room queue. Requires JWT. Operator only.

**Success:** `204 No Content`

### GET /api/media/:id/download

Download a server-hosted media file. Supports HTTP `Range` header for resume.

- `200` — full file (includes `Accept-Ranges: bytes`)
- `206` — partial content (when `Range` header provided)
- `400` — media is external, not server-hosted
- `404` — media or file not found

---

## Socket.IO Connection

Connect with the JWT in the `auth` handshake:

```ts
const socket = io("http://localhost:3000", {
  auth: { token: "<jwt>" }
});
```

The server verifies the token on connection. If invalid or missing, the connection is rejected.

---

## Models

### RoomState

```ts
{
  id: string;
  name: string;
  operatorId: string;
  capacity: number;             // max users (default 10)
  isPublic: boolean;            // visible in lobby (default true)
  settings: RoomSettings;
  currentMedia: Media | null;
  queue: Media[];
  playbackState: PlaybackState;
}
```

### RoomSettings

```ts
{
  waitForNewUsers: boolean;     // pause when someone joins (default: false)
  syncThreshold: number;        // seconds of drift before force-resync (default: 5)
  autoplayNext: boolean;        // auto-advance queue (default: true)
}
```

### Media

```ts
{
  id: string;
  filename: string;
  size: number;                 // bytes
  duration: number;             // seconds
  source: MediaSource;
}
```

### MediaSource

```ts
{
  type: "server" | "external";
  path?: string;                // file path on server (when type = "server")
  url?: string;                 // external URL (when type = "external")
}
```

### PlaybackState

```ts
{
  status: "idle" | "waiting" | "playing" | "paused";
  currentTime: number;          // seconds
  lastUpdated: number;          // unix timestamp ms
}
```

Status meanings:
- `idle` — nothing loaded or playback was stopped
- `waiting` — media loaded, waiting for users to download
- `playing` — active playback
- `paused` — playback paused

### RoomSummary

Lightweight room info returned by the lobby endpoint and `lobby:update` event.

```ts
{
  id: string;
  name: string;
  userCount: number;
  capacity: number;
  currentMedia: { filename: string; duration?: number } | null;
  status: "idle" | "waiting" | "playing" | "paused";
  currentTime?: number;
}
```

### UserState

```ts
{
  userId: string;
  displayName: string;
  roomId: string;
  isOperator: boolean;
  mediaState: UserMediaState;
  playbackState: UserPlaybackState;
  connection: UserConnection;
}
```

### UserMediaState

```ts
{
  mediaId: string | null;
  downloadProgress: number;     // 0–100
  isDownloaded: boolean;
}
```

### UserPlaybackState

```ts
{
  currentTime: number;          // seconds
  isPlaying: boolean;
  isSynced: boolean;
  drift: number;                // seconds (negative = behind operator)
}
```

### UserConnection

```ts
{
  status: "connected" | "disconnected";
  lastHeartbeat: number;        // unix timestamp ms
}
```

---

## Socket.IO Events — Client → Server

### room:join

Join (or create) a room. The first user to join becomes the operator.

```ts
socket.emit("room:join", { roomId: string, displayName: string }, callback?);
```

**Callback response:** `{ success: boolean, error?: string }`

**Server behavior:**
- Creates the room if `roomId` does not exist yet. **Guests cannot auto-create rooms** — they can only join existing rooms.
- First joiner becomes operator.
- Rejects with `"Room is full"` if at capacity.
- Emits `room:state` back to the joining client.
- Emits `room:userJoined` to all other clients in the room.
- If `waitForNewUsers` is enabled and room was playing, pauses with `playback:pause` (reason: `"waiting_for_user"`).
- Starts the sync loop for the room.
- Broadcasts `lobby:update` to lobby subscribers.

### room:leave

Leave the current room.

```ts
socket.emit("room:leave", { roomId: string });
```

**Server behavior:**
- Removes user from the room.
- Emits `room:userLeft` to remaining users.
- If the operator left, transfers operator to the next user and emits `room:usersUpdate`.
- If the room is now empty, cleans it up and stops the sync loop.
- Broadcasts `lobby:update` to lobby subscribers.

### lobby:subscribe

Start receiving real-time lobby updates. Immediately sends current room list.

```ts
socket.emit("lobby:subscribe");
```

**Server behavior:**
- Joins the socket to the `"lobby"` room.
- Emits `lobby:update` with all public rooms to the subscriber.

### user:downloadStart

Signal that the client has started downloading a media file.

```ts
socket.emit("user:downloadStart", { roomId: string, mediaId: string });
```

Sets `downloadProgress: 0`, `isDownloaded: false`. Broadcasts `room:usersUpdate`.

### user:downloadProgress

Report download progress.

```ts
socket.emit("user:downloadProgress", { roomId: string, mediaId: string, progress: number });
```

`progress` is 0–100. Auto-sets `isDownloaded: true` when `progress >= 100`. Broadcasts `room:usersUpdate`.

### user:downloadComplete

Signal that the media file is fully downloaded and ready for playback.

```ts
socket.emit("user:downloadComplete", { roomId: string, mediaId: string });
```

Sets `downloadProgress: 100`, `isDownloaded: true`. Broadcasts `room:usersUpdate`. If all users in the room are now ready and the room is in `"waiting"` state, emits `room:allReady`.

### user:downloadError

Report a download failure.

```ts
socket.emit("user:downloadError", { roomId: string, mediaId: string, error: string });
```

Sets `isDownloaded: false` (preserves last progress). Broadcasts `room:usersUpdate`.

### user:playbackUpdate

Report the client's current playback position. Used by the sync engine to calculate drift.

```ts
socket.emit("user:playbackUpdate", { roomId: string, currentTime: number });
```

`currentTime` is in seconds. No broadcast — the sync engine reads this value during its loop.

### op:play

**Operator only.** Start or resume playback.

```ts
socket.emit("op:play", { roomId: string, atTime?: number });
```

If `atTime` is omitted, resumes from current position. Broadcasts `playback:play` to the room.

### op:pause

**Operator only.** Pause playback.

```ts
socket.emit("op:pause", { roomId: string });
```

Broadcasts `playback:pause` to the room.

### op:seek

**Operator only.** Seek to a specific time.

```ts
socket.emit("op:seek", { roomId: string, toTime: number });
```

Broadcasts `playback:seek` to the room.

### op:stop

**Operator only.** Stop playback and reset to idle.

```ts
socket.emit("op:stop", { roomId: string });
```

Sets status to `"idle"`, resets `currentTime` to 0. Broadcasts `playback:stop`.

### op:addMediaUrl

**Operator only.** Add an external URL as media. If the room has no current media, it becomes the current media automatically.

```ts
socket.emit("op:addMediaUrl", { roomId: string, url: string, filename: string });
```

Broadcasts `media:added`. If it became current, also broadcasts `media:changed`. Always broadcasts `queue:updated`.

### op:removeMedia

**Operator only.** Remove a media item from the queue.

```ts
socket.emit("op:removeMedia", { roomId: string, mediaId: string });
```

Broadcasts `media:removed` and `queue:updated`.

### op:queueNext

**Operator only.** Skip to the next item in the queue. Pops the first queue item, sets it as `currentMedia`, resets playback to `"waiting"`.

```ts
socket.emit("op:queueNext", { roomId: string });
```

Broadcasts `media:changed` (with new media) and `queue:updated`.

---

## Socket.IO Events — Server → Client

### room:state

Full room snapshot sent to a client upon joining.

```ts
socket.on("room:state", (state: RoomState & { users: UserState[] }) => {});
```

### room:userJoined

A new user joined the room.

```ts
socket.on("room:userJoined", (user: UserState) => {});
```

### room:userLeft

A user left the room (or disconnected).

```ts
socket.on("room:userLeft", (data: { userId: string }) => {});
```

### room:usersUpdate

The full users list changed (download progress, operator transfer, etc.).

```ts
socket.on("room:usersUpdate", (data: { users: UserState[] }) => {});
```

### room:allReady

All users in the room have finished downloading the current media. The operator can now safely hit play.

```ts
socket.on("room:allReady", () => {});
```

### playback:play

Operator started playback. Client should play from `atTime`.

```ts
socket.on("playback:play", (data: { atTime: number }) => {});
```

### playback:pause

Operator paused playback. Client should pause at `atTime`. May include a `reason` string (e.g. `"waiting_for_user"`).

```ts
socket.on("playback:pause", (data: { atTime: number, reason?: string }) => {});
```

### playback:seek

Operator seeked. Client should jump to `toTime`.

```ts
socket.on("playback:seek", (data: { toTime: number }) => {});
```

### playback:stop

Operator stopped playback. Client should stop and reset.

```ts
socket.on("playback:stop", () => {});
```

### media:added

A new media item was added to the room (queue or as current).

```ts
socket.on("media:added", (data: { media: Media }) => {});
```

### media:removed

A media item was removed from the queue.

```ts
socket.on("media:removed", (data: { mediaId: string }) => {});
```

### media:changed

The currently playing media changed (new media loaded or queue advanced).

```ts
socket.on("media:changed", (data: { currentMedia: Media }) => {});
```

### queue:updated

The queue contents changed.

```ts
socket.on("queue:updated", (data: { queue: Media[] }) => {});
```

### sync:check

Periodic sync check from the server (every 3s while playing). Sent to non-operator users.

```ts
socket.on("sync:check", (data: { operatorTime: number, timestamp: number }) => {});
```

`operatorTime` is the estimated operator playback position (interpolated using wall-clock elapsed time). The client can use this to detect and correct its own drift.

### sync:forceResync

The server detected this client has drifted beyond the room's `syncThreshold`. Client must seek to `toTime` immediately.

```ts
socket.on("sync:forceResync", (data: { toTime: number }) => {});
```

### lobby:update

Updated list of public rooms. Sent when rooms are created, deleted, or when users join/leave.

```ts
socket.on("lobby:update", (data: { rooms: RoomSummary[] }) => {});
```

---

## Operator Validation

All `op:*` events are silently ignored if the emitting user is not the room's current operator. There is no error callback — the event is simply dropped.

## Disconnect Handling

When a socket disconnects, the server automatically performs `room:leave` for every room that socket had joined. This includes operator transfer and empty-room cleanup.

## Sync Engine

- Runs a 3-second interval per active room while `playbackState.status` is `"playing"`.
- Estimates the operator's current time using wall-clock interpolation: `estimatedOpTime = room.currentTime + (now - lastUpdated) / 1000`.
- Computes `drift = userTime - estimatedOpTime` for each non-operator user.
- If `|drift| > syncThreshold`, emits `sync:forceResync` to that user.
- Emits `sync:check` to all non-operator users each cycle.
- The loop starts when the first user joins a room and stops when the room empties.

## Wait-for-Downloads Mode

When `settings.waitForNewUsers` is `true`:
- If a new user joins while playback is `"playing"`, the server auto-pauses with reason `"waiting_for_user"`.
- When all users have `isDownloaded: true` and the room is in `"waiting"` state, the server emits `room:allReady`.
- The operator then manually resumes playback with `op:play`.

## Media Sources

Media can come from two sources:
- **Server-hosted** (`source.type: "server"`) — uploaded via `POST /api/rooms/:id/media/upload`, downloaded via `GET /api/media/:id/download` (supports range requests for resume).
- **External** (`source.type: "external"`) — added via `POST /api/rooms/:id/media/url` or `op:addMediaUrl`. Clients download directly from the external URL.

## Guest Users

Guest users authenticate via `POST /auth/guest` and receive a JWT with `guest: true`. Restrictions:

- **Cannot create rooms** — `POST /api/rooms` returns `403`.
- **Cannot auto-create rooms via socket** — `room:join` with a non-existent `roomId` returns an error instead of creating the room.
- **Cannot become operator** — since they can't create rooms, they will never be the first user in a room.
- **Can join existing rooms** and participate in playback normally.

## Server Configuration

The following environment variables control server behavior:

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | HTTP server port |
| `JWT_SECRET` | `dsync-dev-secret` | Secret used to sign JWTs |
| `SERVER_NAME` | `dSync Server` | Display name returned by `GET /api/server/info` |
| `ALLOW_REGISTRATION` | `false` | Enable `POST /auth/register` |
| `ALLOW_GUESTS` | `true` | Enable `POST /auth/guest` |
