//cloudLinker/src/routes/clipboard.js
const express = require('express');
const router = express.Router();
const { setClipboard, getClipboard } = require('../clipboardStore');
const { requireApiKey } = require('../middleware/auth');

// POST /clipboard
router.post('/', requireApiKey, (req, res) => {
  const { formats, source } = req.body;

  if (!formats || typeof formats !== 'object') {
    return res.status(400).json({ error: 'formats object is required' });
  }

  // Validate that we have at least one format
  if (Object.keys(formats).length === 0) {
    return res.status(400).json({ error: 'At least one clipboard format is required' });
  }

  const clipboardData = {
    formats,
    source: source || 'unknown'
  };

  setClipboard(clipboardData);
  req.broadcastClipboardUpdate(clipboardData);
  res.status(204).send(); // No content
});

// POST /clipboard/legacy (backward compatibility)
router.post('/legacy', requireApiKey, (req, res) => {
  const { type, data } = req.body;

  if (type !== 'text' && type !== 'image') {
    return res.status(400).json({ error: 'Invalid clipboard type' });
  }

  if (typeof data !== 'string') {
    return res.status(400).json({ error: 'Clipboard data must be a string' });
  }

  const formats = {};
  formats[type] = data;

  const clipboardData = {
    formats,
    source: 'legacy'
  };

  setClipboard(clipboardData);
  req.broadcastClipboardUpdate(clipboardData);
  res.status(204).send(); // No content
});

// GET /clipboard
router.get('/', requireApiKey, (req, res) => {
  res.json(getClipboard());
});

module.exports = router;
