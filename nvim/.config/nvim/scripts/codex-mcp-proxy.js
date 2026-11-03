#!/usr/bin/env node
// Fixed-port HTTP MCP → WebSocket MCP proxy for Neovim/codex integration
// Reads the active Neovim WS server from ~/.codex/ide/*.lock on demand.
// Usage: node codex-mcp-proxy.js [http_port]
// The http_port is registered in ~/.codex/config.toml so codex finds it automatically.

"use strict";

const http = require("http");
const net = require("net");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const HTTP_PORT = parseInt(process.argv[2] || "44200");
const IDE_DIR = path.join(os.homedir(), ".codex", "ide");

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

// Return {port, authToken} for the best live Neovim WS lockfile, or null.
function findNeovimWs() {
  let best = null;
  let bestMtime = 0;
  try {
    for (const name of fs.readdirSync(IDE_DIR)) {
      if (!name.endsWith(".lock")) continue;
      const lockPath = path.join(IDE_DIR, name);
      const data = readLockfile(lockPath);
      if (!data || data.transport !== "ws") continue;
      if (!isPidAlive(data.pid)) continue;
      const port = parseInt(name);
      if (!port) continue;
      try {
        const mtime = fs.statSync(lockPath).mtimeMs;
        if (mtime > bestMtime) { bestMtime = mtime; best = { port, authToken: data.authToken }; }
      } catch (_) {}
    }
  } catch (_) {}
  return best;
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

function wsConnect(port, authToken) {
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
      request(obj) {
        return new Promise((res, rej) => {
          pendingRequests.set(obj.id, { resolve: res, reject: rej });
          this.send(obj);
          setTimeout(() => {
            if (pendingRequests.has(obj.id)) {
              pendingRequests.delete(obj.id);
              rej(new Error("WS request timeout id=" + obj.id));
            }
          }, 30000);
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
      if (authToken) lines.push(`x-codex-code-ide-authorization: ${authToken}`);
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
        if (opcode === 0x9) { ws.send({ type: "pong" }); continue; }
        if (opcode !== 0x1 && opcode !== 0x2) continue;

        try {
          const msg = JSON.parse(payload.toString());
          if (msg.id !== undefined && pendingRequests.has(msg.id)) {
            const { resolve: res } = pendingRequests.get(msg.id);
            pendingRequests.delete(msg.id);
            res(msg);
          } else {
            notifyListeners.forEach((fn) => fn(msg));
          }
        } catch (_) {}
      }
    });

    socket.on("error", reject);
    socket.on("close", () => {
      // Reject all pending requests so callers can retry
      for (const [id, { reject: rej }] of pendingRequests) {
        rej(new Error("WS connection closed"));
        pendingRequests.delete(id);
      }
    });
  });
}

// ── Connection cache ─────────────────────────────────────────────────────────

let cachedWs = null;
let cachedPort = null;

async function getWs() {
  // Reuse live connection
  if (cachedWs && !cachedWs.socket.destroyed) return cachedWs;

  const target = findNeovimWs();
  if (!target) throw new Error("No live Neovim WS MCP server found in " + IDE_DIR);

  if (target.port === cachedPort && cachedWs && !cachedWs.socket.destroyed) return cachedWs;

  cachedWs = null;
  cachedPort = null;

  process.stderr.write(`Connecting to Neovim WS MCP on port ${target.port}\n`);
  const ws = await wsConnect(target.port, target.authToken);
  ws.socket.on("close", () => {
    if (cachedWs === ws) { cachedWs = null; cachedPort = null; }
    process.stderr.write("WS connection closed; will reconnect on next request\n");
  });

  // Do MCP initialize handshake
  const initId = "init-" + Date.now();
  await ws.request({
    jsonrpc: "2.0", id: initId, method: "initialize",
    params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "codex-mcp-proxy", version: "1.0" } },
  });
  ws.send({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });

  cachedWs = ws;
  cachedPort = target.port;
  return ws;
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

      if (msg.id === undefined) {
        // Notification — fire and forget
        try { const ws = await getWs(); ws.send(msg); } catch (_) {}
        res.writeHead(202); res.end();
        return;
      }

      try {
        const ws = await getWs();
        const result = await ws.request(msg);
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

// Forward WS notifications to all SSE clients
// (attach after getWs() returns a live connection)
setInterval(() => {
  if (cachedWs && !cachedWs.socket.destroyed) {
    if (!cachedWs._notifyAttached) {
      cachedWs._notifyAttached = true;
      cachedWs.onNotify((msg) => {
        const event = `data: ${JSON.stringify(msg)}\n\n`;
        for (const [sid, res] of sseClients) {
          try { res.write(event); } catch (_) { sseClients.delete(sid); }
        }
      });
    }
  }
}, 500);

server.listen(HTTP_PORT, "127.0.0.1", () => {
  process.stderr.write(`codex-mcp-proxy HTTP MCP on port ${HTTP_PORT} (reads WS port from ${IDE_DIR})\n`);
});