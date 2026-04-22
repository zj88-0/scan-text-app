const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ─── Safety timeout ───────────────────────────────────────────────────────────
// Firebase Functions timeout is set to 120 s in index.js.
// We abort the Groq call at 90 s so the function can still return a clean
// error response to Flutter instead of a cold Firebase timeout (504).
const GROQ_TIMEOUT_MS = 90_000;

/**
 * Sends an image (base64) to Groq Llama 4 Scout and extracts text.
 * AI call logic is unchanged from the original server implementation.
 *
 * @param {string} base64Image - base64-encoded image data (without data URI prefix)
 * @param {string} mimeType    - e.g. 'image/jpeg', 'image/png'
 * @returns {Promise<string>}  - extracted text from the image
 */
async function extractTextFromImage(base64Image, mimeType = 'image/jpeg') {
  const dataUrl = `data:${mimeType};base64,${base64Image}`;

  // AbortController lets us cancel the Groq fetch if it exceeds our budget
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), GROQ_TIMEOUT_MS);

  try {
    const response = await groq.chat.completions.create(
      {
        model: 'meta-llama/llama-4-scout-17b-16e-instruct',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: { url: dataUrl },
              },
              {
                type: 'text',
                text: `You are an OCR assistant for elderly users.
Extract the MAIN, meaningful body text from this image exactly as it appears.
Please IGNORE irrelevant system UI, battery percentages, clocks, times, URLs, and navigation menus if it is a screenshot.
Preserve line breaks and paragraph structure of the actual content.
Do not add any commentary, explanation, or formatting — output strictly the raw extracted text.
If there is no readable text, respond with: [No text found]`,
              },
            ],
          },
        ],
        max_tokens: 2048,
        temperature: 0,
      },
      // Pass the abort signal through the Groq SDK's fetch options
      { signal: controller.signal }
    );

    const content = response.choices?.[0]?.message?.content || '';
    return content.trim();
  } catch (err) {
    if (err.name === 'AbortError') {
      throw new Error('Groq request timed out after 90 seconds');
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = { extractTextFromImage };