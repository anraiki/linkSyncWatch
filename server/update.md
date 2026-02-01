# SyncWatch Backend Updates

## Overview
Building a synchronized media watch party app. Think Napster/Limewire meets movie theater lobby.

---

## Architecture Changes

### Room Lobby System
Rooms are now public "theaters" that users browse and join (like a cinema lobby).

```typescript
GET /api/rooms — returns list of public rooms with:
  - room name
  - user count / capacity
  - current media playing
  - playback status (idle/waiting/playing/paused)
```

### Media Source Flexibility
Media can come from two sources:

```typescript
interface Media {
  id: string;
  filename: string;
  size: number;
  duration?: number;
  
  source: 
    | { type: 'server'; path: string }      // uploaded to our server
    | { type: 'external'; url: string }     // external URL (TorBox, direct links)
}
```

---

## New REST Endpoints

```typescript
// Lobby
GET    /api/rooms                    // list all public rooms
POST   /api/rooms                    // create room
GET    /api/rooms/:id                // room details
DELETE /api/rooms/:id                // delete room (operator only)

// Media management (operator only)
POST   /api/rooms/:id/media/upload   // upload file to server
POST   /api/rooms/:id/media/url      // add external URL as media source
DELETE /api/rooms/:id/media/:mediaId // remove from queue
GET    /api/media/:id/download       // download server-hosted file (with range support for resume)
```

---

## Updated Room Schema

```typescript
interface Room {
  id: string;
  name: string;
  operatorId: string;
  
  capacity: number;           // max users (default 10)
  isPublic: boolean;          // show in lobby list
  
  currentMedia: Media | null;
  queue: Media[];
  
  playbackState: {
    status: 'idle' | 'waiting' | 'playing' | 'paused';
    currentTime: number;
    lastUpdated: number;      // timestamp for drift calc
  };
  
  settings: {
    waitForNewUsers: boolean;   // pause when someone joins
    syncThreshold: number;      // seconds drift before force-resync (default 5)
    autoplayNext: boolean;      // auto-advance queue
  };
}
```

---

## Updated User Schema

```typescript
interface UserState {
  userId visenta: string;
  odisplayName: string;
  roomId: string;
  isOperator: boolean;
  
  mediaState: {
    mediaId: string | null;
    downloadProgress: number;    // 0-100
    isDownloaded: boolean;
  };
  
  playbackState: {
    currentTime: number;
    isPlaying: boolean;
    isSynced: boolean;          // calculated: within threshold of operator
    drift: number;              // seconds off from operator
  };
  
  connection: {
    status: 'connected' | 'disconnected';
    lastHeartbeat: number;
  };
}
```

---

## New Socket Events

### Lobby Events
```typescript
// Client -> Server
'lobby:subscribe'      -> {}                      // start receiving lobby updates

// Server -> Client  
'lobby:update'         <- { rooms: RoomSummary[] } // room list changed
```

### Media Events (Operator)
```typescript
// Client -> Server
'op:addMediaUrl'       -> { roomId: string, url: string, filename: string }
'op:removeMedia'       -> { roomId: string, mediaId: string }
'op:queueNext'         -> { roomId: string }       // skip to next in queue

// Server -> Client (broadcast to room)
'media:added'          <- { media: Media }
'media:removed'        <- { mediaId: string }
'media:changed'        <- { currentMedia: Media }  // now playing changed
'queue:updated'        <- { queue: Media[] }
```

### Download Progress Events
```typescript
// Client -> Server
'user:downloadStart'   -> { roomId: string, mediaId: string }
'user:downloadProgress'-> { roomId: string, mediaId: string, progress: number }
'user:downloadComplete'-> { roomId: string, mediaId: string }
'user:downloadError'   -> { roomId: string, mediaId: string, error: string }

// Server -> Client (broadcast to room)
'room:usersUpdate'     <- { users: UserState[] }   // includes download progress
```

---

## Sync Engine Updates

### Heartbeat Loop (server-side, every 2-3 sec per active room)
```typescript
function syncCheck(room: Room) {
  if (room.playbackState.status !== 'playing') return;
  
  const opTime = room.playbackState.currentTime;
  const now = Date.now();
  
  // Update operator time based on elapsed
  const elapsed = (now - room.playbackState.lastUpdated) / 1000;
  const estimatedOpTime = opTime + elapsed;
  
  room.users.forEach(user => {
    if (user.isOperator) return;
    
    const drift = user.playbackState.currentTime - estimatedOpTime;
    user.playbackState.drift = drift;
    user.playbackState.isSynced = Math.abs(drift) <= room.settings.syncThreshold;
    
    if (!user.playbackState.isSynced) {
      // Force resync this user
      io.to(user.socketId).emit('sync:forceResync', { toTime: estimatedOpTime });
    }
  });
  
  // Broadcast updated user states
  io.to(room.id).emit('room:usersUpdate', { users: room.users });
}
```

### Wait for Downloads Mode
```typescript
// When waitForNewUsers is true and someone joins:
socket.on('room:join', (data) => {
  const room = getRoom(data.roomId);
  
  if (room.settings.waitForNewUsers && room.playbackState.status === 'playing') {
    room.playbackState.status = 'waiting';
    io.to(room.id).emit('playback:pause', { 
      atTime: room.playbackState.currentTime,
      reason: 'waiting_for_user'
    });
  }
});

// Resume when all users ready
function checkAllReady(room: Room) {
  const allReady = room.users.every(u => u.mediaState.isDownloaded);
  
  if (allReady && room.playbackState.status === 'waiting') {
    io.to(room.id).emit('room:allReady', {});
    // Operator can now hit play
  }
}
```

---

## File Download Endpoint

Support range requests for resume capability:

```typescript
// GET /api/media/:id/download
app.get('/api/media/:id/download', (req, res) => {
  const media = getMedia(req.params.id);
  if (media.source.type !== 'server') {
    return res.status(400).json({ error: 'Not server-hosted' });
  }
  
  const filePath = media.source.path;
  const stat = fs.statSync(filePath);
  const fileSize = stat.size;
  const range = req.headers.range;
  
  if (range) {
    // Partial content for resume
    const parts = range.replace(/bytes=/, '').split('-');
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
    const chunkSize = end - start + 1;
    
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunkSize,
      'Content-Type': 'application/octet-stream',
    });
    
    fs.createReadStream(filePath, { start, end }).pipe(res);
  } else {
    res.writeHead(200, {
      'Content-Length': fileSize,
      'Content-Type': 'application/octet-stream',
    });
    fs.createReadStream(filePath).pipe(res);
  }
});
```

---

## Room Summary for Lobby

```typescript
interface RoomSummary {
  id: string;
  name: string;
  userCount: number;
  capacity: number;
  currentMedia: {
    filename: string;
    duration?: number;
  } | null;
  status: 'idle' | 'waiting' | 'playing' | 'paused';
  currentTime?: number;
}

// GET /api/rooms returns RoomSummary[]
```

---

## Database Schema (SQLite)

```sql
CREATE TABLE rooms (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  operator_id TEXT NOT NULL,
  capacity INTEGER DEFAULT 10,
  is_public BOOLEAN DEFAULT true,
  settings JSON,
  created_at INTEGER,
  updated_at INTEGER
);

CREATE TABLE media (
  id TEXT PRIMARY KEY,
  room_id TEXT,
  filename TEXT NOT NULL,
  size INTEGER,
  duration INTEGER,
  source_type TEXT NOT NULL,  -- 'server' | 'external'
  source_path TEXT,           -- file path or URL
  queue_order INTEGER,
  created_at INTEGER,
  FOREIGN KEY (room_id) REFERENCES rooms(id)
);

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  created_at INTEGER
);

-- Active state kept in memory, not DB
```

---

## Notes

- Client will be Flutter with media_kit for native video playback (no transcoding)
- Server just coordinates sync + hosts/proxies files
- External URLs (TorBox etc) = clients download direct from source
- Server-hosted files = clients download from our server with range support
