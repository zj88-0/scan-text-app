const { onRequest } = require("firebase-functions/v2/https");
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const ocrRoutes = require('./routes/ocr');

const app = express();

// origin: true reflects the request origin — required for Firebase + Flutter CORS
app.use(cors({ origin: true }));
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));

app.use('/api/ocr', ocrRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Elderly Reader Server is running' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(500).json({ success: false, error: err.message || 'Internal server error' });
});

// ─── Firebase Functions v2 Export ───────────────────────────────────────────
// No app.listen() — Firebase manages the HTTP lifecycle.
// Region: asia-southeast1 (Singapore) — closest to Flutter app users in SEA.
exports.api = onRequest(
  {
    region: "asia-southeast1",
    memory: "1GiB",        // Needed for base64 image buffering
    timeoutSeconds: 120,   // Groq AI calls can take several seconds
    maxInstances: 10,      // Cap concurrency; raise if traffic grows
    concurrency: 80,       // Requests handled per instance (v2 default is 80)
  },
  app
);