const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

/**
 * Sends an image (base64 or URL) to Groq Llama 4 Scout and extracts text.
 * @param {string} base64Image - base64-encoded image data (without data URI prefix)
 * @param {string} mimeType - e.g. 'image/jpeg', 'image/png'
 * @returns {Promise<string>} - extracted text from the image
 */
async function extractTextFromImage(base64Image, mimeType = 'image/jpeg') {
  const dataUrl = `data:${mimeType};base64,${base64Image}`;

  const response = await groq.chat.completions.create({
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
  });

  const content = response.choices?.[0]?.message?.content || '';
  return content.trim();
}

module.exports = { extractTextFromImage };
