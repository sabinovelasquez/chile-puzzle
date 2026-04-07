const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;
const BIND = process.env.BIND || '0.0.0.0';
const URL_PREFIX = process.env.URL_PREFIX || ''; // e.g. '/zoominchile' in production
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

// Image upload + optimization via sharp
const sharp = require('sharp');
const uploadsDir = path.join(__dirname, 'public', 'uploads');

app.post('/api/upload', upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No image uploaded' });
  try {
    const optimized = req.file.path + '.jpg';
    await sharp(req.file.path)
      .rotate() // auto-rotate from EXIF
      .resize(2000, 2000, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 85 })
      .toFile(optimized);
    fs.unlinkSync(req.file.path);
    const finalName = path.basename(req.file.path) + '.jpg';
    res.json({ url: `${URL_PREFIX}/uploads/${finalName}` });
  } catch (e) {
    // Fallback: keep original
    const ext = path.extname(req.file.originalname).toLowerCase() || '.jpg';
    const newPath = req.file.path + ext;
    fs.renameSync(req.file.path, newPath);
    res.json({ url: `${URL_PREFIX}/uploads/${path.basename(newPath)}` });
  }
});

// Optimize all existing images in-place (one-time migration)
app.post('/api/optimize-images', async (req, res) => {
  const files = fs.readdirSync(uploadsDir).filter(f => /\.(jpg|jpeg|png)$/i.test(f));
  const results = [];
  for (const file of files) {
    const filePath = path.join(uploadsDir, file);
    const sizeBefore = fs.statSync(filePath).size;
    try {
      const tmpPath = filePath + '.tmp';
      await sharp(filePath)
        .rotate()
        .resize(2000, 2000, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 85 })
        .toFile(tmpPath);
      const sizeAfter = fs.statSync(tmpPath).size;
      fs.renameSync(tmpPath, filePath);
      results.push({ file, before: sizeBefore, after: sizeAfter, saved: sizeBefore - sizeAfter });
    } catch (e) {
      results.push({ file, error: e.message });
    }
  }
  res.json({ optimized: results.length, results });
});

// Clean up unused uploads (not referenced by any location)
app.post('/api/cleanup-uploads', (req, res) => {
  const read = (f) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return []; } };
  const locations = read(path.join(dataDir, 'locations.json'));
  const usedFiles = new Set();
  locations.forEach(loc => {
    [loc.image, loc.thumbnail].forEach(url => {
      if (url) usedFiles.add(url.split('/').pop());
    });
  });
  const allFiles = fs.readdirSync(uploadsDir).filter(f => /\.(jpg|jpeg|png|heic|heif)$/i.test(f));
  const unused = allFiles.filter(f => !usedFiles.has(f));
  unused.forEach(f => fs.unlinkSync(path.join(uploadsDir, f)));
  res.json({ deleted: unused.length, files: unused, kept: allFiles.length - unused.length });
});

// CRUD routes
const dataDir = path.join(__dirname, 'data');

// Locations: sorted by zone order, then requiredPoints ascending
const locFile = path.join(dataDir, 'locations.json');
const zoneFile = path.join(dataDir, 'zones.json');
app.get('/api/locations', (req, res) => {
  const read = (f) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return []; } };
  const zones = read(zoneFile);
  const zoneOrder = {};
  zones.forEach(z => { zoneOrder[z.id] = z.order ?? 99; });
  const locations = read(locFile);
  locations.sort((a, b) => (zoneOrder[a.region] ?? 99) - (zoneOrder[b.region] ?? 99) || (a.requiredPoints || 0) - (b.requiredPoints || 0));
  res.json(locations);
});
app.post('/api/locations', (req, res) => {
  fs.writeFile(locFile, JSON.stringify(req.body, null, 2), (err) => {
    if (err) return res.status(500).json({ error: 'Failed to write data' });
    res.json({ success: true });
  });
});

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

app.listen(PORT, BIND, () => {
  console.log(`✨ Admin server running at http://${BIND}:${PORT}${URL_PREFIX}`);
});
