const {onRequest} = require("firebase-functions/v2/https");
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const ocrRoutes = require("./routes/ocr");
const translateRoutes = require("./routes/translate"); // ← NEW

const app = express();

// origin: true reflects the request origin — required for Firebase + Flutter
app.use(cors({origin: true}));
app.use(express.json({limit: "20mb"}));
app.use(express.urlencoded({extended: true, limit: "20mb"}));

app.use("/api/ocr", ocrRoutes);
app.use("/api/translate", translateRoutes); // ← NEW

app.get("/health", (req, res) => {
  res.json({status: "ok", message: "Elderly Reader Server is running"});
});

// Global error handler
app.use((err, req, res, next) => {
  console.error("Error:", err.message);
  res.status(500).json({
    success: false,
    error: err.message || "Internal server error",
  });
});

// ─── Firebase Functions v2 Export ──────────────────────────────────────────
exports.api = onRequest(
    {
      region: "asia-southeast1",
      memory: "1GiB",
      timeoutSeconds: 120,
      maxInstances: 10,
      concurrency: 80,
    },
    app,
);
