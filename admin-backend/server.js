const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;
const upload = multer({ dest: path.join(__dirname, 'public', 'uploads') });

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Helper for JSON file CRUD routes
function jsonFileRoute(routePath, filePath) {
  app.get(routePath, (req, res) => {
    fs.readFile(filePath, 'utf8', (err, data) => {
      if (err) return res.status(500).json({ error: 'Failed to read data' });
      try { res.json(JSON.parse(data)); } catch { res.json([]); }
    });
  });
  app.post(routePath, (req, res) => {
    fs.writeFile(filePath, JSON.stringify(req.body, null, 2), (err) => {
      if (err) return res.status(500).json({ error: 'Failed to write data' });
      res.json({ success: true });
    });
  });
}

// File upload (converts HEIC/HEIF to JPEG via heif-convert)
const { execSync } = require('child_process');
let heifConvert = false;
try { execSync('which heif-convert', { stdio: 'ignore' }); heifConvert = true; } catch {}

app.post('/api/upload', upload.single('image'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No image uploaded' });
  const ext = path.extname(req.file.originalname).toLowerCase();
  const isHeic = ext === '.heic' || ext === '.heif';
  if (heifConvert && isHeic) {
    const jpgPath = req.file.path + '.jpg';
    try {
      execSync(`heif-convert -q 90 "${req.file.path}" "${jpgPath}"`);
      fs.unlinkSync(req.file.path);
      res.json({ url: `/uploads/${path.basename(jpgPath)}` });
    } catch (e) {
      const newPath = req.file.path + ext;
      fs.renameSync(req.file.path, newPath);
      res.json({ url: `/uploads/${path.basename(newPath)}` });
    }
  } else {
    const newPath = req.file.path + ext;
    fs.renameSync(req.file.path, newPath);
    res.json({ url: `/uploads/${path.basename(newPath)}` });
  }
});

// CRUD routes
const dataDir = path.join(__dirname, 'data');
jsonFileRoute('/api/locations', path.join(dataDir, 'locations.json'));
jsonFileRoute('/api/zones', path.join(dataDir, 'zones.json'));
jsonFileRoute('/api/trophies', path.join(dataDir, 'trophies.json'));
jsonFileRoute('/api/scoring', path.join(dataDir, 'scoring.json'));

// Composite config endpoint (single call from Flutter)
app.get('/api/config', (req, res) => {
  const read = (file) => new Promise((resolve) => {
    fs.readFile(path.join(dataDir, file), 'utf8', (err, data) => {
      if (err) return resolve(file.includes('scoring') ? {} : []);
      try { resolve(JSON.parse(data)); } catch { resolve(file.includes('scoring') ? {} : []); }
    });
  });
  Promise.all([read('zones.json'), read('scoring.json'), read('trophies.json')])
    .then(([zones, scoring, trophies]) => res.json({ zones, scoring, trophies }));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✨ Admin server running at http://0.0.0.0:${PORT}`);
});
