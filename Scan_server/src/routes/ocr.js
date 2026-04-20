const express = require('express');
const multer = require('multer');
const { extractTextFromImage } = require('../services/groqService');
const { translateToAllLanguages } = require('../services/translationService');

const router = express.Router();

// Use memory storage — we pass base64 directly to Groq
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

/**
 * POST /api/ocr/process
 * Accepts multipart image upload, extracts text via Groq, translates to all languages.
 * Returns: { success, originalText, translations: { en, zh, ms, ta } }
 */
router.post('/process', upload.single('image'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'No image file provided' });
    }

    const base64Image = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype;

    console.log(`Processing image: ${req.file.originalname} (${mimeType}, ${req.file.size} bytes)`);

    // Step 1: Extract text using Groq Llama 4 Scout
    const originalText = await extractTextFromImage(base64Image, mimeType);
    console.log(`Extracted text (${originalText.length} chars)`);

    // Step 2: Translate to all 4 languages
    const translations = await translateToAllLanguages(originalText);
    console.log('Translation complete');

    return res.json({
      success: true,
      originalText,
      translations,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/ocr/process-base64
 * Accepts JSON body with { image: "<base64>", mimeType: "image/jpeg" }
 * Useful for Flutter when sending bytes directly.
 */
router.post('/process-base64', express.json({ limit: '20mb' }), async (req, res, next) => {
  try {
    const { image, mimeType = 'image/jpeg' } = req.body;

    if (!image) {
      return res.status(400).json({ success: false, error: 'No image data provided' });
    }

    // Strip data URL prefix if present
    const base64Clean = image.replace(/^data:image\/\w+;base64,/, '');

    console.log(`Processing base64 image (${base64Clean.length} chars)`);

    const originalText = await extractTextFromImage(base64Clean, mimeType);
    console.log(`Extracted text (${originalText.length} chars)`);

    const translations = await translateToAllLanguages(originalText);
    console.log('Translation complete');

    return res.json({
      success: true,
      originalText,
      translations,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
