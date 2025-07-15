//cloudLinker/src/routes/clipboard.js
const express = require('express');
const router = express.Router();
const { setClipboard, getClipboard } = require('../clipboardStore');
const { requireApiKey } = require('../middleware/auth');

// POST /clipboard
router.post('/', requireApiKey, (req, res) => {
  const { type, data } = req.body;

  if (type !== 'text' && type !== 'image') {
    return res.status(400).json({ error: 'Invalid clipboard type' });
  }

  if (typeof data !== 'string') {
    return res.status(400).json({ error: 'Clipboard data must be a string' });
  }

  setClipboard({ type, data });
  req.broadcastClipboardUpdate({ type, data });
  res.status(204).send(); // No content
});

// GET /clipboard
router.get('/', requireApiKey, (req, res) => {
  res.json(getClipboard());
});

module.exports = router;
