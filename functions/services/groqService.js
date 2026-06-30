const Groq = require("groq-sdk");

const groq = new Groq({apiKey: process.env.GROQ_API_KEY});

// ─── Safety timeout ──────────────────────────────────────────────────────────
// Firebase Functions timeout is set to 120 s in index.js.
// We abort the Groq call at 90 s so the function can still return a clean
// error response to Flutter instead of a cold Firebase timeout (504).
const GROQ_TIMEOUT_MS = 90000;

/**
 * Sends an image (base64) to Groq Llama 3.2 11B Vision and extracts text.
 *
 * @param {string} base64Image - base64-encoded image data (no data URI prefix)
 * @param {string} mimeType    - e.g. 'image/jpeg', 'image/png'
 * @return {Promise<string>}  - extracted text from the image
 */
async function extractTextFromImage(base64Image, mimeType = "image/jpeg") {
  const dataUrl = `data:${mimeType};base64,${base64Image}`;

  // AbortController lets us cancel the Groq fetch if it exceeds our budget
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), GROQ_TIMEOUT_MS);

  try {
    const response = await groq.chat.completions.create(
        {
          model: "qwen/qwen3.6-27b",
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "image_url",
                  image_url: {url: dataUrl},
                },
                {
                  type: "text",
                  text: `You are an OCR assistant for elderly users.
Extract the MAIN, meaningful body text from this image exactly as it appears.
Correct for any image rotation or orientation
to ensure text is extracted in its proper reading order.
Please IGNORE irrelevant system UI, battery percentages, clocks, times, URLs,
and navigation menus if it is a screenshot.
Preserve line breaks and paragraph structure of the actual content.
CRITICAL: Do NOT add any conversational filler, do NOT show your thinking
process, and do NOT describe the image (e.g. do not say "The image shows...").
Return ONLY the raw transcribed text. If there is no readable text,
respond exactly with: [No text found]`,
                },
              ],
            },
          ],
          max_tokens: 2048,
          temperature: 0,
        },
        // Pass the abort signal through the Groq SDK's fetch options
        {signal: controller.signal},
    );

    // response.choices?.[0] rewritten to avoid optional chaining on brackets
    const choices = response.choices;
    let content =
      choices && choices[0] && choices[0].message ?
        choices[0].message.content :
        "";

    // Strip out the <think> block that reasoning models (like Qwen) generate
    content = content.replace(/<think>[\s\S]*?<\/think>\n*/g, "");

    return content.trim();
  } catch (err) {
    if (err.name === "AbortError") {
      throw new Error("Groq request timed out after 90 seconds");
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = {extractTextFromImage};
