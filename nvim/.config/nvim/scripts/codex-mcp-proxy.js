#!/usr/bin/env node
// Fixed-port HTTP MCP → WebSocket MCP proxy for Neovim/codex integration
// Reads the active Neovim MCP WS server from Claude Code or Codex IDE lockfiles.
// Usage: node codex-mcp-proxy.js --stdio | [http_port]
// Codex launches this proxy with --stdio from ~/.codex/config.toml.

"use strict";

const http = require("http");
const net = require("net");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const STDIO_MODE = process.argv[2] === "--stdio";
const HTTP_PORT = parseInt((STDIO_MODE ? process.argv[3] : process.argv[2]) || "44200", 10);
const IDE_SOURCES = [
  {
    kind: "claude",
    dir: path.join(process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude"), "ide"),
    authHeader: "x-claude-code-ide-authorization",
  },
  {
    kind: "codex",
    dir: path.join(os.homedir(), ".codex", "ide"),
    authHeader: "x-codex-code-ide-authorization",
  },
];

// ── Lockfile discovery ───────────────────────────────────────────────────────

function readLockfile(lockPath) {
  try {
    return JSON.parse(fs.readFileSync(lockPath, "utf8"));
  } catch (_) {
    return null;
  }
}

function isPidAlive(pid) {
  if (!pid) return false;
  try { process.kill(pid, 0); return true; } catch (_) { return false; }
}

function pathContains(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === "" || (relative !== ".." && !relative.startsWith(".." + path.sep) && !path.isAbsolute(relative));
}

function workspaceMatchScore(cwd, workspaceFolders) {
  let best = 0;
  for (const folder of Array.isArray(workspaceFolders) ? workspaceFolders : []) {
    if (typeof folder !== "string" || folder === "") continue;
    const workspace = path.resolve(folder);
    if (workspace === cwd) best = Math.max(best, 3000000 + workspace.length);
    else if (pathContains(workspace, cwd)) best = Math.max(best, 2000000 + workspace.length);
    else if (pathContains(cwd, workspace)) best = Math.max(best, 1000000 + workspace.length);
  }
  return best;
}

// Prefer the Claude Neovim MCP server, which provides blocking openDiff, and
// select the lock that best matches this Codex server's workspace.
function findNeovimWs() {
  const cwd = path.resolve(process.cwd());
  const candidates = [];

  for (const source of IDE_SOURCES) {
    let names;
    try { names = fs.readdirSync(source.dir); } catch (_) { continue; }

    for (const name of names) {
      if (!name.endsWith(".lock")) continue;
      const lockPath = path.join(source.dir, name);
      const data = readLockfile(lockPath);
      if (!data || data.transport !== "ws" || !isPidAlive(data.pid)) continue;
      const port = parseInt(name, 10);
      if (!port) continue;
      try {
        const mtime = fs.statSync(lockPath).mtimeMs;
        candidates.push({
          port,
          authToken: data.authToken,
          authHeader: source.authHeader,
          kind: source.kind,
          key: lockPath,
          mtime,
          workspaceScore: workspaceMatchScore(cwd, data.workspaceFolders),
        });
      } catch (_) {}
    }
  }

  if (candidates.length === 0) return null;
  const matching = candidates.filter((candidate) => candidate.workspaceScore > 0);
  const pool = matching.length > 0 ? matching : candidates;
  const claudeCandidates = pool.filter((candidate) => candidate.kind === "claude");
  const preferred = claudeCandidates.length > 0 ? claudeCandidates : pool;
  preferred.sort((a, b) => b.workspaceScore - a.workspaceScore || b.mtime - a.mtime);
  return preferred[0];
}

function encodeWsControlFrame(opcode, payload) {
  if (payload.length > 125) throw new Error("WebSocket control payload exceeds 125 bytes");
  const mask = crypto.randomBytes(4);
  const header = Buffer.from([0x80 | opcode, 0x80 | payload.length]);
  const maskedPayload = Buffer.alloc(payload.length);
  for (let i = 0; i < payload.length; i++) maskedPayload[i] = payload[i] ^ mask[i % 4];
  return Buffer.concat([header, mask, maskedPayload]);
}

// ── Minimal WebSocket client (no external deps) ──────────────────────────────

function encodeWsFrame(payload) {
  const len = payload.length;
  let header;
  if (len < 126) {
    header = Buffer.alloc(2);
    header[0] = 0x81;
    header[1] = len;
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x81;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([header, payload]);
}

function wsConnect(port, authToken, authHeader) {
  return new Promise((resolve, reject) => {
    const key = crypto.randomBytes(16).toString("base64");
    const socket = net.createConnection(port, "127.0.0.1");
    let buf = Buffer.alloc(0);
    let upgraded = false;
    const pendingRequests = new Map();
    const notifyListeners = [];

    const ws = {
      socket,
      pendingRequests,
      notifyListeners,
      send(obj) {
        socket.write(encodeWsFrame(Buffer.from(JSON.stringify(obj))));
      },
      pong(payload) {
        socket.write(encodeWsControlFrame(0xA, payload));
      },
      request(obj, timeoutMs = 30000) {
        return new Promise((res, rej) => {
          const pending = { resolve: res, reject: rej, timer: null };
          if (timeoutMs > 0) {
            pending.timer = setTimeout(() => {
              if (pendingRequests.get(obj.id) === pending) {
                pendingRequests.delete(obj.id);
                rej(new Error("WS request timeout id=" + obj.id));
              }
            }, timeoutMs);
          }
          pendingRequests.set(obj.id, pending);
          this.send(obj);
        });
      },
      onNotify(fn) { notifyListeners.push(fn); },
      close() { try { socket.destroy(); } catch (_) {} },
    };

    socket.on("connect", () => {
      const lines = [
        `GET / HTTP/1.1`,
        `Host: 127.0.0.1:${port}`,
        `Upgrade: websocket`,
        `Connection: Upgrade`,
        `Sec-WebSocket-Key: ${key}`,
        `Sec-WebSocket-Version: 13`,
      ];
      if (authToken) lines.push(`${authHeader}: ${authToken}`);
      socket.write(lines.join("\r\n") + "\r\n\r\n");
    });

    socket.on("data", (chunk) => {
      buf = Buffer.concat([buf, chunk]);

      if (!upgraded) {
        const end = buf.indexOf("\r\n\r\n");
        if (end === -1) return;
        const headers = buf.slice(0, end).toString();
        if (!headers.includes("101")) {
          reject(new Error("WS upgrade failed: " + headers.slice(0, 200)));
          socket.destroy();
          return;
        }
        upgraded = true;
        buf = buf.slice(end + 4);
        resolve(ws);
      }

      while (buf.length >= 2) {
        const b0 = buf[0], b1 = buf[1];
        const masked = !!(b1 & 0x80);
        let payloadLen = b1 & 0x7f;
        let offset = 2;
        if (payloadLen === 126) {
          if (buf.length < 4) break;
          payloadLen = buf.readUInt16BE(2); offset = 4;
        } else if (payloadLen === 127) {
          if (buf.length < 10) break;
          payloadLen = Number(buf.readBigUInt64BE(2)); offset = 10;
        }
        if (masked) offset += 4;
        if (buf.length < offset + payloadLen) break;

        let payload = buf.slice(offset, offset + payloadLen);
        if (masked) {
          const mask = buf.slice(offset - 4, offset);
          for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
        }
        buf = buf.slice(offset + payloadLen);

        const opcode = b0 & 0x0f;
        if (opcode === 0x8) { ws.close(); return; }
        if (opcode === 0x9) { ws.pong(payload); continue; }
        if (opcode !== 0x1 && opcode !== 0x2) continue;

        try {
          const msg = JSON.parse(payload.toString());
          if (msg.id !== undefined && pendingRequests.has(msg.id)) {
            const pending = pendingRequests.get(msg.id);
            pendingRequests.delete(msg.id);
            if (pending.timer) clearTimeout(pending.timer);
            pending.resolve(msg);
          } else {
            notifyListeners.forEach((fn) => fn(msg));
          }
        } catch (_) {}
      }
    });

    socket.on("error", reject);
    socket.on("close", () => {
      // Reject all pending requests so callers can retry
      for (const [id, pending] of pendingRequests) {
        if (pending.timer) clearTimeout(pending.timer);
        pending.reject(new Error("WS connection closed"));
        pendingRequests.delete(id);
      }
    });
  });
}

// ── Connection cache ─────────────────────────────────────────────────────────

let cachedWs = null;
let cachedTargetKey = null;
let cachedInitializeResult = null;

async function getWs() {
  const target = findNeovimWs();
  if (!target) {
    const ideDirs = IDE_SOURCES.map((source) => source.dir).join(", ");
    throw new Error(`No live Neovim WS MCP server found for ${process.cwd()} in ${ideDirs}`);
  }

  if (cachedWs && !cachedWs.socket.destroyed && target.key === cachedTargetKey) return cachedWs;

  if (cachedWs && !cachedWs.socket.destroyed) cachedWs.close();
  cachedWs = null;
  cachedTargetKey = null;
  cachedInitializeResult = null;

  process.stderr.write(`Connecting to Neovim WS MCP (${target.kind}) on port ${target.port}\n`);
  const ws = await wsConnect(target.port, target.authToken, target.authHeader);
  if (STDIO_MODE) ws.onNotify((msg) => process.stdout.write(JSON.stringify(msg) + "\n"));
  ws.socket.on("close", () => {
    if (cachedWs === ws) {
      cachedWs = null;
      cachedTargetKey = null;
      cachedInitializeResult = null;
    }
    process.stderr.write("WS connection closed; will reconnect on next request\n");
  });

  // Initialize the upstream MCP connection once, then mirror its result to clients.
  const initId = "init-" + Date.now();
  const initResponse = await ws.request({
    jsonrpc: "2.0", id: initId, method: "initialize",
    params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "codex-mcp-proxy", version: "1.0" } },
  });
  if (initResponse.error) {
    ws.close();
    throw new Error(`Neovim MCP initialize failed: ${initResponse.error.message}`);
  }
  cachedInitializeResult = initResponse.result;
  ws.send({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });

  cachedWs = ws;
  cachedTargetKey = target.key;
  return ws;
}

// Codex sends paths relative to its own working directory, but Neovim resolves
// them against its cwd, which can be a subdirectory of Codex's. A relative path
// that misses makes openDiff treat the file as new, so the diff has no original
// side and nothing is highlighted. Anchor the paths to this proxy's cwd instead.
function absolutizePath(p) {
  if (typeof p !== "string" || p === "") return p;
  const expanded = p === "~" || p.startsWith("~/") ? path.join(os.homedir(), p.slice(1)) : p;
  return path.resolve(process.cwd(), expanded);
}

function normalizeOpenDiff(msg) {
  if (msg.method !== "tools/call" || !msg.params || msg.params.name !== "openDiff") return msg;
  const args = msg.params.arguments || {};
  return {
    ...msg,
    params: {
      ...msg.params,
      arguments: {
        ...args,
        old_file_path: absolutizePath(args.old_file_path),
        new_file_path: absolutizePath(args.new_file_path),
      },
    },
  };
}

async function forwardMcpMessage(msg) {
  const ws = await getWs();
  if (msg.method === "initialize") return { jsonrpc: "2.0", id: msg.id, result: cachedInitializeResult };
  if (msg.method === "notifications/initialized") return null;
  if (msg.id === undefined || !msg.method) {
    ws.send(msg);
    return null;
  }
  const timeoutMs = msg.method === "tools/call" ? 0 : 30000;
  return ws.request(normalizeOpenDiff(msg), timeoutMs);
}

// ── HTTP MCP server ──────────────────────────────────────────────────────────

// SSE subscribers: sessionId -> http.ServerResponse
const sseClients = new Map();

const server = http.createServer((req, res) => {
  if (req.url !== "/mcp") {
    res.writeHead(404); res.end("Not Found"); return;
  }

  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Mcp-Session-Id, Authorization");

  if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }

  if (req.method === "GET") {
    const sessionId = req.headers["mcp-session-id"] || ("sse-" + Date.now());
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "Mcp-Session-Id": sessionId,
    });
    res.write(": keep-alive\n\n");
    sseClients.set(sessionId, res);
    req.on("close", () => sseClients.delete(sessionId));
    return;
  }

  if (req.method === "DELETE") {
    const sid = req.headers["mcp-session-id"];
    if (sid && sseClients.has(sid)) {
      try { sseClients.get(sid).end(); } catch (_) {}
      sseClients.delete(sid);
    }
    res.writeHead(200); res.end(); return;
  }

  if (req.method === "POST") {
    let body = "";
    req.on("data", (c) => { body += c; });
    req.on("end", async () => {
      let msg;
      try { msg = JSON.parse(body); } catch (_) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "invalid JSON" }));
        return;
      }

      try {
        const result = await forwardMcpMessage(msg);
        if (msg.id === undefined || !msg.method) {
          res.writeHead(202);
          res.end();
          return;
        }
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(result));
      } catch (e) {
        process.stderr.write(`Proxy error: ${e.message}\n`);
        res.writeHead(503, { "Content-Type": "application/json" });
        res.end(JSON.stringify({
          jsonrpc: "2.0", id: msg.id,
          error: { code: -32000, message: e.message },
        }));
      }
    });
    return;
  }

  res.writeHead(405); res.end("Method Not Allowed");
});

function writeStdioMessage(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

function startStdio() {
  let buffer = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    buffer += chunk;
    let newline;
    while ((newline = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, newline);
      buffer = buffer.slice(newline + 1);
      if (!line.trim()) continue;

      let msg;
      try {
        msg = JSON.parse(line);
      } catch (_) {
        writeStdioMessage({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } });
        continue;
      }

      forwardMcpMessage(msg).then((result) => {
        if (msg.id !== undefined && msg.method) writeStdioMessage(result);
      }).catch((error) => {
        process.stderr.write(`Proxy error: ${error.message}\n`);
        if (msg.id !== undefined && msg.method) {
          writeStdioMessage({ jsonrpc: "2.0", id: msg.id, error: { code: -32000, message: error.message } });
        }
      });
    }
  });
  process.stdin.on("end", () => {
    if (cachedWs) cachedWs.close();
  });
  process.stdin.on("error", (error) => process.stderr.write(`MCP stdin error: ${error.message}\n`));
  process.stdin.resume();
}

if (STDIO_MODE) {
  startStdio();
} else {
  // Forward WS notifications to all HTTP/SSE clients.
  setInterval(() => {
    if (cachedWs && !cachedWs.socket.destroyed && !cachedWs._notifyAttached) {
      cachedWs._notifyAttached = true;
      cachedWs.onNotify((msg) => {
        const event = `data: ${JSON.stringify(msg)}\n\n`;
        for (const [sid, res] of sseClients) {
          try { res.write(event); } catch (_) { sseClients.delete(sid); }
        }
      });
    }
  }, 500);

  server.listen(HTTP_PORT, "127.0.0.1", () => {
    process.stderr.write(`codex-mcp-proxy HTTP MCP on port ${HTTP_PORT} (reads IDE locks from ${IDE_SOURCES.map((source) => source.dir).join(", ")})\n`);
  });
}
