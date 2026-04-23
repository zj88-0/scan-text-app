const Groq = require("groq-sdk");

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

const GROQ_TIMEOUT_MS = 60000; // 60 s — translation is faster than OCR

// ─── Language display names (for the prompt) ─────────────────────────────
const LANG_NAMES = {
  af: "Afrikaans",
  ar: "Arabic",
  be: "Belarusian",
  bg: "Bulgarian",
  bn: "Bengali",
  ca: "Catalan",
  cs: "Czech",
  cy: "Welsh",
  da: "Danish",
  de: "German",
  el: "Greek",
  en: "English",
  eo: "Esperanto",
  es: "Spanish",
  et: "Estonian",
  fa: "Persian",
  fi: "Finnish",
  fr: "French",
  ga: "Irish",
  gl: "Galician",
  gu: "Gujarati",
  he: "Hebrew",
  hi: "Hindi",
  hr: "Croatian",
  hu: "Hungarian",
  id: "Indonesian",
  is: "Icelandic",
  it: "Italian",
  ja: "Japanese",
  ka: "Georgian",
  kn: "Kannada",
  ko: "Korean",
  lt: "Lithuanian",
  lv: "Latvian",
  mk: "Macedonian",
  mr: "Marathi",
  ms: "Malay",
  mt: "Maltese",
  nl: "Dutch",
  no: "Norwegian",
  pl: "Polish",
  pt: "Portuguese",
  ro: "Romanian",
  ru: "Russian",
  sk: "Slovak",
  sl: "Slovenian",
  sq: "Albanian",
  sv: "Swedish",
  sw: "Swahili",
  ta: "Tamil",
  te: "Telugu",
  th: "Thai",
  tl: "Filipino",
  tr: "Turkish",
  uk: "Ukrainian",
  ur: "Urdu",
  vi: "Vietnamese",
  zh: "Chinese (Simplified)",
};

/**
 * Translates English text to the target language using Groq Llama 4,
 * producing a natural, context-aware translation rather than a
 * word-for-word literal mapping.
 *
 * Rules applied:
 *  - Proper nouns (names, brand names, abbreviations) that have no
 *    standard translation are left in their original form.
 *  - Abbreviations/acronyms that do have a recognised equivalent in
 *    the target language are translated.
 *  - The structure and paragraph breaks of the source text are preserved.
 *  - No commentary, explanations, or extra formatting is added.
 *
 * @param {string} text       - English source text extracted by OCR
 * @param {string} targetCode - BCP-47-style language code (e.g. 'zh','ms')
 * @return {Promise<string>}  - Translated text
 */
async function translateText(text, targetCode) {
  if (!text || text.trim() === "" || text === "[No text found]") return text;
  if (targetCode === "en") return text;

  const targetLangName = LANG_NAMES[targetCode] || targetCode.toUpperCase();

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), GROQ_TIMEOUT_MS);

  try {
    const response = await groq.chat.completions.create(
        {
          model: "meta-llama/llama-4-scout-17b-16e-instruct",
          messages: [
            {
              role: "system",
              content:
                `You are a professional translator specialising in ` +
                `natural, fluent ${targetLangName} for everyday readers.\n\n` +
                `RULES — follow these exactly:\n` +
                `1. Translate the user's text into ${targetLangName}.\n` +
                `2. Produce a natural, fluent translation — NOT a ` +
                `word-for-word literal mapping. The result should read ` +
                `as if it were originally written in ${targetLangName}.\n` +
                `3. Proper nouns (people's names, place names, brand ` +
                `names, product names) that have NO standard ` +
                `${targetLangName} equivalent must be left exactly as ` +
                `they appear in the source.\n` +
                `4. Abbreviations and acronyms: if they have a widely ` +
                `recognised ${targetLangName} equivalent, use it. ` +
                `Otherwise keep the original form.\n` +
                `5. Preserve paragraph breaks and line structure.\n` +
                `6. Output ONLY the translated text. Do not add any ` +
                `explanation, commentary, notes, or formatting.`,
            },
            {
              role: "user",
              content: text,
            },
          ],
          max_tokens: 4096,
          temperature: 0.2,
        },
        {signal: controller.signal},
    );

    const choices = response.choices;
    const content =
      choices && choices[0] && choices[0].message ?
        choices[0].message.content :
        "";
    return content.trim();
  } catch (err) {
    if (err.name === "AbortError") {
      throw new Error("Translation request timed out after 60 seconds");
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = {translateText};
