const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const sharp = require('sharp');
const { db, rowToLocation, locationToParams, rowToZone, rowToTrophy, rowToScoring } = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;
const BIND = process.env.BIND || '0.0.0.0';
const URL_PREFIX = process.env.URL_PREFIX || '';
const uploadsDir = path.join(__dirname, 'public', 'uploads');
const upload = multer({ dest: uploadsDir });

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ============================================================
// LOCATIONS — Paginated GET with filters
// ============================================================
app.get('/api/locations', (req, res) => {
  const page = parseInt(req.query.page) || 0;
  const limit = parseInt(req.query.limit) || 999;
  const zone = req.query.zone || null;
  const q = req.query.q || null;
  const isNew = req.query.new === '1';
  const ids = req.query.ids ? req.query.ids.split(',').filter(Boolean) : null;

  let where = [];
  let params = {};

  if (ids && ids.length > 0) {
    // When filtering by IDs, ignore other filters
    const placeholders = ids.map((id, i) => `@id${i}`).join(',');
    ids.forEach((id, i) => { params[`id${i}`] = id; });
    where.push(`l.id IN (${placeholders})`);
  } else {
    if (zone) {
      where.push('l.region = @zone');
      params.zone = zone;
    }
    if (q) {
      where.push('(l.name_en LIKE @q OR l.name_es LIKE @q)');
      params.q = `%${q}%`;
    }
    if (isNew) {
      where.push("l.created_at >= datetime('now', '-7 days')");
    }
  }

  const whereClause = where.length ? 'WHERE ' + where.join(' AND ') : '';

  const countSql = `SELECT COUNT(*) as total FROM locations l ${whereClause}`;
  const total = db.prepare(countSql).get(params).total;

  const dataSql = `
    SELECT l.* FROM locations l
    LEFT JOIN zones z ON l.region = z.id
    ${whereClause}
    ORDER BY COALESCE(z."order", 99) ASC, l.required_points ASC
    LIMIT @limit OFFSET @offset
  `;
  params.limit = limit;
  params.offset = page * limit;

  const rows = db.prepare(dataSql).all(params);
  const data = rows.map(rowToLocation);

  res.json({ data, total, page, pageSize: limit });
});

// CREATE location
app.post('/api/locations', (req, res) => {
  const obj = req.body;
  if (!obj.id) return res.status(400).json({ error: 'Missing id' });

  const params = locationToParams(obj);
  try {
    db.prepare(`
      INSERT INTO locations
        (id, name_en, name_es, region, required_points, latitude, longitude,
         image, thumbnail, tip_en, tip_es, crop_x, crop_y, crop_w, crop_h, difficulty)
      VALUES
        (@id, @name_en, @name_es, @region, @required_points, @latitude, @longitude,
         @image, @thumbnail, @tip_en, @tip_es, @crop_x, @crop_y, @crop_w, @crop_h, @difficulty)
    `).run(params);
    res.json({ success: true, id: obj.id });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// UPDATE location
app.put('/api/locations/:id', (req, res) => {
  const obj = { ...req.body, id: req.params.id };
  const params = locationToParams(obj);
  params.updated_at = new Date().toISOString().replace('T', ' ').slice(0, 19);

  const result = db.prepare(`
    UPDATE locations SET
      name_en = @name_en, name_es = @name_es, region = @region,
      required_points = @required_points, latitude = @latitude, longitude = @longitude,
      image = @image, thumbnail = @thumbnail,
      tip_en = @tip_en, tip_es = @tip_es,
      crop_x = @crop_x, crop_y = @crop_y, crop_w = @crop_w, crop_h = @crop_h,
      difficulty = @difficulty, updated_at = @updated_at
    WHERE id = @id
  `).run(params);

  if (result.changes === 0) return res.status(404).json({ error: 'Not found' });
  res.json({ success: true });
});

// DELETE location
app.delete('/api/locations/:id', (req, res) => {
  const result = db.prepare('DELETE FROM locations WHERE id = @id').run({ id: req.params.id });
  if (result.changes === 0) return res.status(404).json({ error: 'Not found' });
  res.json({ success: true });
});

// ============================================================
// ZONES — Full array GET/POST (few items)
// ============================================================
app.get('/api/zones', (req, res) => {
  const rows = db.prepare('SELECT * FROM zones ORDER BY "order" ASC').all();
  res.json(rows.map(rowToZone));
});

app.post('/api/zones', (req, res) => {
  const zones = req.body;
  if (!Array.isArray(zones)) return res.status(400).json({ error: 'Expected array' });

  const tx = db.transaction(() => {
    db.prepare('DELETE FROM zones').run();
    const stmt = db.prepare('INSERT INTO zones (id, name_en, name_es, "order", icon) VALUES (@id, @name_en, @name_es, @order, @icon)');
    for (const z of zones) {
      stmt.run({
        id: z.id,
        name_en: z.name?.en || '',
        name_es: z.name?.es || '',
        order: z.order ?? 99,
        icon: z.icon || 'landscape',
      });
    }
  });

  try { tx(); res.json({ success: true }); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
// TROPHIES — Full array GET/POST (few items)
// ============================================================
app.get('/api/trophies', (req, res) => {
  const rows = db.prepare('SELECT * FROM trophies').all();
  res.json(rows.map(rowToTrophy));
});

app.post('/api/trophies', (req, res) => {
  const trophies = req.body;
  if (!Array.isArray(trophies)) return res.status(400).json({ error: 'Expected array' });

  const tx = db.transaction(() => {
    db.prepare('DELETE FROM trophies').run();
    const stmt = db.prepare(`
      INSERT INTO trophies (id, name_en, name_es, description_en, description_es, icon, type, condition_json)
      VALUES (@id, @name_en, @name_es, @description_en, @description_es, @icon, @type, @condition_json)
    `);
    for (const t of trophies) {
      stmt.run({
        id: t.id,
        name_en: t.name?.en || '',
        name_es: t.name?.es || '',
        description_en: t.description?.en || '',
        description_es: t.description?.es || '',
        icon: t.icon || 'emoji_events',
        type: t.type || 'milestone',
        condition_json: JSON.stringify(t.condition || {}),
      });
    }
  });

  try { tx(); res.json({ success: true }); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
// SCORING — Single object GET/POST
// ============================================================
app.get('/api/scoring', (req, res) => {
  const row = db.prepare('SELECT * FROM scoring WHERE id = 1').get();
  res.json(rowToScoring(row));
});

app.post('/api/scoring', (req, res) => {
  const s = req.body;
  db.prepare(`
    UPDATE scoring SET
      base_points_3 = @bp3, base_points_4 = @bp4,
      base_points_5 = @bp5, base_points_6 = @bp6,
      time_bonus_threshold_secs = @tbt, time_bonus_points = @tbp,
      move_efficiency_bonus_pct = @meb
    WHERE id = 1
  `).run({
    bp3: s.basePoints?.['3'] ?? 50,
    bp4: s.basePoints?.['4'] ?? 100,
    bp5: s.basePoints?.['5'] ?? 200,
    bp6: s.basePoints?.['6'] ?? 350,
    tbt: s.timeBonusThresholdSecs ?? 60,
    tbp: s.timeBonusPoints ?? 50,
    meb: s.moveEfficiencyBonusPercent ?? 20,
  });
  res.json({ success: true });
});

// ============================================================
// CONFIG — Composite endpoint for Flutter
// ============================================================
app.get('/api/config', (req, res) => {
  const zones = db.prepare('SELECT * FROM zones ORDER BY "order" ASC').all().map(rowToZone);
  const scoring = rowToScoring(db.prepare('SELECT * FROM scoring WHERE id = 1').get());
  const trophies = db.prepare('SELECT * FROM trophies').all().map(rowToTrophy);
  res.json({ zones, scoring, trophies });
});

// ============================================================
// IMAGE UPLOAD + THUMBNAIL
// ============================================================
app.post('/api/upload', upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No image uploaded' });
  try {
    const baseName = path.basename(req.file.path);
    const optimized = req.file.path + '.jpg';

    // Full-size optimized image
    await sharp(req.file.path)
      .rotate()
      .resize(2000, 2000, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 85 })
      .toFile(optimized);

    // Thumbnail (400px wide)
    const thumbName = baseName + '_thumb.jpg';
    const thumbPath = path.join(uploadsDir, thumbName);
    await sharp(optimized)
      .resize(400, null, { withoutEnlargement: true })
      .jpeg({ quality: 70 })
      .toFile(thumbPath);

    // Clean up original upload
    fs.unlinkSync(req.file.path);

    const fullName = baseName + '.jpg';
    res.json({
      url: `${URL_PREFIX}/uploads/${fullName}`,
      thumbnail: `${URL_PREFIX}/uploads/${thumbName}`,
    });
  } catch (e) {
    // Fallback: keep original
    const ext = path.extname(req.file.originalname).toLowerCase() || '.jpg';
    const newPath = req.file.path + ext;
    fs.renameSync(req.file.path, newPath);
    const fallbackName = path.basename(newPath);
    res.json({
      url: `${URL_PREFIX}/uploads/${fallbackName}`,
      thumbnail: `${URL_PREFIX}/uploads/${fallbackName}`,
    });
  }
});

// Batch generate thumbnails for existing locations
app.post('/api/generate-thumbnails', async (req, res) => {
  const rows = db.prepare('SELECT id, image, thumbnail FROM locations WHERE thumbnail = image').all();
  const results = [];

  for (const row of rows) {
    const fileName = row.image.split('/').pop();
    const filePath = path.join(uploadsDir, fileName);
    if (!fs.existsSync(filePath)) {
      results.push({ id: row.id, error: 'File not found: ' + fileName });
      continue;
    }
    try {
      const thumbName = fileName.replace(/\.[^.]+$/, '') + '_thumb.jpg';
      const thumbPath = path.join(uploadsDir, thumbName);
      await sharp(filePath)
        .resize(400, null, { withoutEnlargement: true })
        .jpeg({ quality: 70 })
        .toFile(thumbPath);

      const thumbUrl = row.image.replace(fileName, thumbName);
      db.prepare('UPDATE locations SET thumbnail = @thumb WHERE id = @id').run({ thumb: thumbUrl, id: row.id });
      results.push({ id: row.id, thumbnail: thumbUrl });
    } catch (e) {
      results.push({ id: row.id, error: e.message });
    }
  }

  res.json({ processed: results.length, results });
});

// Optimize all existing images in-place
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

// Clean up unused uploads
app.post('/api/cleanup-uploads', (req, res) => {
  const rows = db.prepare('SELECT image, thumbnail FROM locations').all();
  const usedFiles = new Set();
  rows.forEach(row => {
    [row.image, row.thumbnail].forEach(url => {
      if (url) usedFiles.add(url.split('/').pop());
    });
  });
  const allFiles = fs.readdirSync(uploadsDir).filter(f => /\.(jpg|jpeg|png|heic|heif)$/i.test(f));
  const unused = allFiles.filter(f => !usedFiles.has(f));
  unused.forEach(f => fs.unlinkSync(path.join(uploadsDir, f)));
  res.json({ deleted: unused.length, files: unused, kept: allFiles.length - unused.length });
});

// ============================================================
// LEADERBOARD
// ============================================================
const BANNED_INITIALS = ['FUK', 'FKU', 'KKK', 'WTF', 'DIK', 'DIE', 'ASS', 'FAG', 'SEX', 'CUM', 'TIT', 'PIS', 'COK'];

app.get('/api/leaderboard', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200);
  const rows = db.prepare(`
    SELECT id, initials, total_points, puzzles_completed, created_at
    FROM leaderboard ORDER BY total_points DESC, puzzles_completed DESC
    LIMIT ?
  `).all(limit);

  const entries = rows.map((row, i) => ({
    rank: i + 1,
    initials: row.initials,
    totalPoints: row.total_points,
    puzzlesCompleted: row.puzzles_completed,
    createdAt: row.created_at,
  }));

  res.json({ entries });
});

app.post('/api/leaderboard', (req, res) => {
  const { initials, totalPoints, puzzlesCompleted } = req.body;

  if (!initials || !/^[A-Z]{3}$/.test(initials)) {
    return res.status(400).json({ error: 'Initials must be exactly 3 uppercase letters' });
  }
  if (BANNED_INITIALS.includes(initials)) {
    return res.status(400).json({ error: 'Invalid initials' });
  }
  if (typeof totalPoints !== 'number' || totalPoints < 0) {
    return res.status(400).json({ error: 'Invalid totalPoints' });
  }

  const result = db.prepare(`
    INSERT INTO leaderboard (initials, total_points, puzzles_completed)
    VALUES (@initials, @totalPoints, @puzzlesCompleted)
  `).run({
    initials,
    totalPoints: totalPoints || 0,
    puzzlesCompleted: puzzlesCompleted || 0,
  });

  // Calculate rank
  const rank = db.prepare(`
    SELECT COUNT(*) + 1 as rank FROM leaderboard
    WHERE total_points > @points
  `).get({ points: totalPoints || 0 }).rank;

  res.json({ id: result.lastInsertRowid, rank });
});

// ============================================================
// START
// ============================================================
app.listen(PORT, BIND, () => {
  console.log(`✨ Admin server running at http://${BIND}:${PORT}${URL_PREFIX}`);
});
