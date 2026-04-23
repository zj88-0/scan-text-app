const express = require("express");
const crypto = require("crypto");
const {translateText} = require("../services/groqTranslationService");

// eslint-disable-next-line new-cap
const router = express.Router();

// ─── In-Memory Cache ─────────────────────────────────────────────────────
// Keyed by SHA-256(text + targetCode) — prevents duplicate Groq calls when
// the same user switches back to a language they already translated.
// Each instance keeps its own cache; across cold-starts the Flutter app's
// local SavedText cache is the primary deduplication layer.

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const translationCache = new Map();

/**
 * Builds a SHA-256 cache key from the target language code and source text.
 *
 * @param {string} text       - Source text to translate
 * @param {string} targetCode - BCP-47 language code, e.g. "zh" or "ms"
 * @return {string}           - Hex-encoded SHA-256 digest
 */
function cacheKey(text, targetCode) {
  return crypto
      .createHash("sha256")
      .update(targetCode + ":" + text)
      .digest("hex");
}

/**
 * Returns the cached translation for the given key, or null if the entry
 * is missing or has expired.
 *
 * @param {string} key - Cache key produced by {@link cacheKey}
 * @return {string|null} - Cached translated text, or null on miss/expiry
 */
function getCached(key) {
  const entry = translationCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
    translationCache.delete(key);
    return null;
  }
  return entry.value;
}

/**
 * Stores a translated string in the in-memory cache.
 *
 * @param {string} key   - Cache key produced by {@link cacheKey}
 * @param {string} value - Translated text to cache
 * @return {void}
 */
function setCache(key, value) {
  translationCache.set(key, {value, timestamp: Date.now()});
}

// Periodic cleanup — removes entries older than 2× TTL
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of translationCache.entries()) {
    if (now - entry.timestamp > CACHE_TTL_MS * 2) {
      translationCache.delete(key);
    }
  }
}, 60000);

// ─── Routes ──────────────────────────────────────────────────────────────

/**
 * POST /api/translate/smart
 *
 * Body: { text: string, targetLang: string }
 *   text        — English source text (from OCR)
 *   targetLang  — BCP-47-style code, e.g. "zh", "ms", "ta"
 *
 * Response: { success: true, translatedText: string }
 *         | { success: false, error: string }
 */
router.post("/smart", express.json({limit: "2mb"}), async (req, res, next) => {
  try {
    const {text, targetLang} = req.body;

    if (!text || typeof text !== "string" || text.trim() === "") {
      return res.status(400).json({
        success: false,
        error: "No text provided",
      });
    }

    if (!targetLang || typeof targetLang !== "string") {
      return res.status(400).json({
        success: false,
        error: "No targetLang provided",
      });
    }

    // English pass-through — no Groq call needed
    if (targetLang === "en") {
      return res.json({success: true, translatedText: text});
    }

    const key = cacheKey(text, targetLang);

    // Check server-side cache first (helps burst traffic within one instance)
    const cached = getCached(key);
    if (cached) {
      console.log(
          `[translate] Cache hit for lang=${targetLang}` +
          ` key=${key.slice(0, 12)}…`,
      );
      return res.json({success: true, translatedText: cached});
    }

    console.log(
        `[translate] Translating ${text.length} chars to ${targetLang}` +
        ` key=${key.slice(0, 12)}…`,
    );

    const translatedText = await translateText(text, targetLang);

    setCache(key, translatedText);

    console.log(
        `[translate] Done: ${translatedText.length} chars to ${targetLang}`,
    );

    return res.json({success: true, translatedText});
  } catch (err) {
    next(err);
  }
});

module.exports = router;
