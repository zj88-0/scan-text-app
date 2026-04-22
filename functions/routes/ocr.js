const express = require('express');
const multer = require('multer');
const crypto = require('crypto');
const { extractTextFromImage } = require('../services/groqService');

const router = express.Router();

// ─── In-Memory Deduplication Cache ──────────────────────────────────────────
// Prevents duplicate Groq calls when Flutter retries the same image quickly
// (e.g. network hiccup, double-tap, or aggressive timeout/retry logic).
//
// Key   : SHA-256 hash of the raw image bytes (or base64 string)
// Value : { promise, timestamp }
//
// Firebase Functions v2 with concurrency > 1 keeps the process warm between
// requests, so this cache is effective within a single instance lifetime.
// Each entry auto-expires after CACHE_TTL_MS to avoid stale memory growth.

const CACHE_TTL_MS = 30_000; // 30 s — long enough to absorb retries
const pendingRequests = new Map();

/**
 * Returns a SHA-256 hex digest of a Buffer or string.
 * Used as a stable cache key for image content.
 */
function hashContent(data) {
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Wraps an async factory in deduplication logic.
 * If an identical request (same hash) is already in flight, the new caller
 * awaits the same Promise instead of firing a second Groq API call.
 * Entries are evicted after CACHE_TTL_MS regardless of outcome.
 */
async function deduplicatedExtract(cacheKey, factory) {
  // Return the in-flight promise if one exists for this image
  if (pendingRequests.has(cacheKey)) {
    console.log(`[cache] Duplicate request detected (key: ${cacheKey.slice(0, 12)}…) — reusing in-flight result`);
    return pendingRequests.get(cacheKey).promise;
  }

  // Create the real extraction promise and cache it
  const promise = factory().finally(() => {
    // Evict after TTL so the cache doesn't grow unboundedly
    setTimeout(() => pendingRequests.delete(cacheKey), CACHE_TTL_MS);
  });

  pendingRequests.set(cacheKey, { promise, timestamp: Date.now() });
  return promise;
}

// Periodic cleanup of stale cache entries (safety net for long-lived instances)
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of pendingRequests.entries()) {
    if (now - entry.timestamp > CACHE_TTL_MS * 2) {
      pendingRequests.delete(key);
    }
  }
}, 60_000); // run every 60 s

// ─── Multer (multipart upload) ───────────────────────────────────────────────
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: { fileSize: 15 * 1024 * 1024 }, // 15 MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype === 'application/octet-stream') {
      cb(null, true);
    } else {
      cb(new Error(`Invalid file type: ${file.mimetype}. Only image files are allowed.`));
    }
  },
});

// ─── Routes ──────────────────────────────────────────────────────────────────

/**
 * POST /api/ocr/process
 * Multipart image upload → extracted text via Groq.
 * Deduplication: keyed on SHA-256 of raw image bytes.
 */
router.post('/process', upload.single('image'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'No image file provided' });
    }

    const { buffer, mimetype, originalname, size } = req.file;
    const cacheKey = hashContent(buffer);

    console.log(`[process] ${originalname} (${mimetype}, ${size} bytes) key=${cacheKey.slice(0, 12)}…`);

    const originalText = await deduplicatedExtract(cacheKey, () => {
      const base64Image = buffer.toString('base64');
      return extractTextFromImage(base64Image, mimetype);
    });

    console.log(`[process] Extracted ${originalText.length} chars`);
    return res.json({ success: true, originalText });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/ocr/process-base64
 * JSON body { image: "<base64>", mimeType: "image/jpeg" } → extracted text.
 * Deduplication: keyed on SHA-256 of the cleaned base64 string.
 * Flutter apps commonly use this endpoint when working with image pickers
 * that return base64 data directly.
 */
router.post('/process-base64', express.json({ limit: '20mb' }), async (req, res, next) => {
  try {
    const { image, mimeType = 'image/jpeg' } = req.body;

    if (!image) {
      return res.status(400).json({ success: false, error: 'No image data provided' });
    }

    // Strip the data URI prefix if Flutter sends a full data URL
    const base64Clean = image.replace(/^data:image\/\w+;base64,/, '');
    const cacheKey = hashContent(base64Clean);

    console.log(`[process-base64] ${base64Clean.length} chars, key=${cacheKey.slice(0, 12)}…`);

    const originalText = await deduplicatedExtract(cacheKey, () =>
      extractTextFromImage(base64Clean, mimeType)
    );

    console.log(`[process-base64] Extracted ${originalText.length} chars`);
    return res.json({ success: true, originalText });
  } catch (err) {
    next(err);
  }
});

module.exports = router;