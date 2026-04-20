require('dotenv').config();
const express = require('express');
const cors = require('cors');
const ocrRoutes = require('./routes/ocr');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));

app.use('/api/ocr', ocrRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Elderly Reader Server is running' });
});

app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(500).json({ success: false, error: err.message || 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
