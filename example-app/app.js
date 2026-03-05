const express = require('express');
const app = express();
const PORT = process.env.PORT || 80;

// Root endpoint - displays welcome message
app.get('/', (req, res) => {
  res.send('Welcome to CMC TS');
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
