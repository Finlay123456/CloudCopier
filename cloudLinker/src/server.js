const express = require('express');
const cors = require('cors');
const clipboardRoutes = require('./routes/clipboard');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' })); // Allow large image payloads

app.use('/clipboard', clipboardRoutes);

app.listen(PORT, () => {
  console.log(`Clipboard server running at http://localhost:${PORT}`);
});
