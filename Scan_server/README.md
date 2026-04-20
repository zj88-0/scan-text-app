# Elderly Reader — Node.js Backend

Express server that handles image-to-text extraction (via Groq Llama 4 Scout) and multi-language translation.

## Setup

```bash
npm install
cp .env.example .env
# Edit .env and add your GROQ_API_KEY
npm run dev   # development with nodemon
npm start     # production
```

## API Endpoints

### `POST /api/ocr/process`
Multipart form upload.  
Field: `image` (file)  
Returns: `{ success, originalText, translations: { en, zh, ms, ta } }`

### `POST /api/ocr/process-base64`
JSON body: `{ image: "<base64string>", mimeType: "image/jpeg" }`  
Returns: `{ success, originalText, translations: { en, zh, ms, ta } }`

### `GET /health`
Returns server health status.

## Environment Variables

| Variable | Description |
|---|---|
| `PORT` | Server port (default 3000) |
| `GROQ_API_KEY` | Your Groq API key (get free at console.groq.com) |
