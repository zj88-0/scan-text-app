const translate = require('translate');

// Supported language codes
const SUPPORTED_LANGUAGES = {
  en: 'English',
  zh: 'Chinese (Simplified)',
  ms: 'Malay',
  ta: 'Tamil',
};

/**
 * Translate text into all supported languages.
 * @param {string} text - source text (any language)
 * @returns {Promise<{en: string, zh: string, ms: string, ta: string}>}
 */
async function translateToAllLanguages(text) {
  if (!text || text.trim() === '' || text === '[No text found]') {
    const empty = { en: text, zh: text, ms: text, ta: text };
    return empty;
  }

  const results = { en: text, zh: text, ms: text, ta: text };

  const targets = ['en', 'zh', 'ms', 'ta'];

  await Promise.allSettled(
    targets.map(async (lang) => {
      try {
        // translate package uses Google Translate free endpoint
        const translated = await translate(text, { to: lang });
        results[lang] = translated;
      } catch (err) {
        console.warn(`Translation to ${lang} failed:`, err.message);
        // Keep original text as fallback
        results[lang] = text;
      }
    })
  );

  return results;
}

module.exports = { translateToAllLanguages, SUPPORTED_LANGUAGES };
