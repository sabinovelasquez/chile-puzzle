const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const dataFile = path.join(__dirname, 'data', 'locations.json');

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/locations', (req, res) => {
    fs.readFile(dataFile, 'utf8', (err, data) => {
        if (err) return res.status(500).json({ error: 'Failed to read data' });
        try {
            res.json(JSON.parse(data));
        } catch (e) {
            res.json([]);
        }
    });
});

app.post('/api/locations', (req, res) => {
    const locations = req.body;
    fs.writeFile(dataFile, JSON.stringify(locations, null, 2), (err) => {
        if (err) return res.status(500).json({ error: 'Failed to write data' });
        res.json({ success: true });
    });
});

app.listen(PORT, () => {
    console.log(`✨ Admin server running at http://localhost:${PORT}`);
});
