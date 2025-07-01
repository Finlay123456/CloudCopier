const express = require('express');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');
const clipboardRoutes = require('./routes/clipboard');

const app = express();
const server = http.createServer(app); // <-- wrap express in http server
const wss = new WebSocket.Server({ server }); // <-- attach WebSocket

const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Save connected clients
const clients = new Set();

wss.on('connection', ws => {
  clients.add(ws);
  ws.on('close', () => clients.delete(ws));
});

function broadcastClipboardUpdate(clipboard) {
  const msg = JSON.stringify({ type: 'clipboardUpdate', clipboard });
  for (const ws of clients) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }
}

app.use((req, res, next) => {
  req.broadcastClipboardUpdate = broadcastClipboardUpdate;
  next();
});

app.use('/clipboard', clipboardRoutes);

server.listen(PORT, () => {
  console.log(`Clipboard server running at http://localhost:${PORT}`);
});
