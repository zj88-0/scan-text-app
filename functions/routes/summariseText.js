const express = require("express");
const Groq = require("groq-sdk");

// eslint-disable-next-line new-cap
const router = express.Router();

const groq = new Groq({apiKey: process.env.GROQ_API_KEY});

const GROQ_TIMEOUT_MS = 60000; // 60 s

/**
 * POST /api/summarise-text
 *
 * Body: { text: string, url: string }
 *   text — The raw text content of the website
 *   url — The URL the text was fetched from
 *
 * Response: { success: true, summary: string, url: string }
 *         | { success: false, error: string }
 */
router.post("/", express.json({limit: "1mb"}), async (req, res, next) => {
  try {
    const {text, url} = req.body;

    if (!text || typeof text !== "string" || text.trim() === "") {
      return res.status(400).json({
        success: false,
        error: "No text provided",
      });
    }

    if (!url || typeof url !== "string" || url.trim() === "") {
      return res.status(400).json({
        success: false,
        error: "No URL provided",
      });
    }

    // Truncate to avoid exceeding Groq token limit
    // (~12 000 chars = ~3 000 tokens)
    const truncated = text.slice(0, 12000);

    console.log(
        `[summarise-text] Got ${text.length} chars from ${url}, ` +
        `sending ${truncated.length} to Groq`,
    );

    // Step 2: Summarise with Groq
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), GROQ_TIMEOUT_MS);

    let summary;
    try {
      const response = await groq.chat.completions.create(
          {
            model: "llama-3.1-8b-instant",
            messages: [
              {
                role: "system",
                content:
                  "You are a helpful assistant for elderly users. " +
                  "Summarise the provided web page content in 3 to 5 clear, " +
                  "simple sentences. Use plain language. " +
                  "Focus on the main topic and key takeaways. " +
                  "Do not include URLs, navigation menus, " +
                  "or boilerplate text. " +
                  "Output only the summary -- no titles, " +
                  "no bullet points.",
              },
              {
                role: "user",
                content: truncated,
              },
            ],
            max_tokens: 512,
            temperature: 0.3,
          },
          {signal: controller.signal},
      );

      const choices = response.choices;
      summary =
        choices && choices[0] && choices[0].message ?
          choices[0].message.content.trim() :
          "";
    } catch (err) {
      if (err.name === "AbortError") {
        throw new Error("Groq summarisation timed out");
      }
      throw err;
    } finally {
      clearTimeout(timeoutId);
    }

    if (!summary) {
      return res.status(500).json({
        success: false,
        error: "Failed to generate summary",
      });
    }

    console.log(
        `[summarise-text] Summary: ${summary.length} chars`,
    );

    return res.json({
      success: true,
      summary,
      url,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
