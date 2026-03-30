const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;
const dataFile = path.join(__dirname, 'data', 'locations.json');
const upload = multer({ dest: path.join(__dirname, 'public', 'uploads') });

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/upload', upload.single('image'), (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No image uploaded' });
    const ext = path.extname(req.file.originalname);
    const newPath = req.file.path + ext;
    fs.renameSync(req.file.path, newPath);
    res.json({ url: `/uploads/${path.basename(newPath)}` });
});

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
