const express = require('express');
const cors = require('cors');
const { requireApiKey } = require('./auth');
const { setClipboard, getClipboard } = require('./clipboardStore');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '100mb' })); // Large limit for images and files
app.use(express.urlencoded({ limit: '100mb', extended: true }));

// Routes

// POST /clipboard - Set clipboard content
app.post('/clipboard', requireApiKey, (req, res) => {
  const { formats, source } = req.body;
  
  if (!formats || typeof formats !== 'object') {
    return res.status(400).json({ error: 'formats object is required' });
  }
  
  if (Object.keys(formats).length === 0) {
    return res.status(400).json({ error: 'At least one format is required' });
  }
  
  setClipboard({
    formats,
    source: source || 'http'
  });
  
  res.status(204).send();
});

// GET /clipboard - Get current clipboard content
app.get('/clipboard', requireApiKey, (req, res) => {
  res.json(getClipboard());
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: Date.now()
  });
});

app.listen(PORT, () => {
  console.log(`Clipboard server running on port ${PORT}`);
  console.log(`API Key: ${process.env.API_KEY}`);
});