require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const sharp = require('sharp');
const { db, rowToLocation, locationToParams, rowToZone, rowToTrophy, rowToScoring, rowToTester } = require('./db');

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
  let limit = parseInt(req.query.limit) || 999;
  const zone = req.query.zone || null;
  const q = req.query.q || null;
  const isNew = req.query.new === '1';
  const all = req.query.all === '1';
  const ids = req.query.ids ? req.query.ids.split(',').filter(Boolean) : null;

  let where = [];
  let params = {};

  if (ids && ids.length > 0) {
    // When filtering by IDs, ignore other filters (but still respect `all`)
    const placeholders = ids.map((id, i) => `@id${i}`).join(',');
    ids.forEach((id, i) => { params[`id${i}`] = id; });
    where.push(`l.id IN (${placeholders})`);
    if (!all) where.push('l.active = 1');
  } else {
    // Default: hide inactive stubs from Flutter. Admin opts in with ?all=1
    if (!all) where.push('l.active = 1');
    if (zone) {
      where.push('l.region = @zone');
      params.zone = zone;
    }
    if (q) {
      where.push('(l.name_en LIKE @q OR l.name_es LIKE @q)');
      params.q = `%${q}%`;
    }
    if (isNew) {
      // Show latest locations, ordered by creation date
      limit = Math.min(parseInt(req.query.limit) || 25, 100);
    }
  }

  const whereClause = where.length ? 'WHERE ' + where.join(' AND ') : '';

  const countSql = `SELECT COUNT(*) as total FROM locations l ${whereClause}`;
  const total = db.prepare(countSql).get(params).total;

  const orderBy = isNew
    ? 'ORDER BY l.created_at DESC'
    : 'ORDER BY COALESCE(z."order", 99) ASC, l.required_points ASC';
  const dataSql = `
    SELECT l.* FROM locations l
    LEFT JOIN zones z ON l.region = z.id
    ${whereClause}
    ${orderBy}
    LIMIT @limit OFFSET @offset
  `;
  params.limit = limit;
  params.offset = page * limit;

  const rows = db.prepare(dataSql).all(params);
  const data = rows.map(rowToLocation);

  res.json({ data, total, page, pageSize: limit });
});

const LOCATION_INSERT_COLS = `
  id, name_en, name_es, region, required_points, latitude, longitude,
  image, thumbnail, original_image, original_width, original_height, active,
  tip_en, tip_es,
  tip_normal_en, tip_normal_es, tip_hard_en, tip_hard_es, tip_expert_en, tip_expert_es,
  crop_x, crop_y, crop_w, crop_h,
  crop_easy_x, crop_easy_y, crop_easy_w, crop_easy_h,
  crop_normal_x, crop_normal_y, crop_normal_w, crop_normal_h,
  crop_hard_x, crop_hard_y, crop_hard_w, crop_hard_h,
  crop_expert_x, crop_expert_y, crop_expert_w, crop_expert_h,
  difficulty
`;
const LOCATION_INSERT_VALS = `
  @id, @name_en, @name_es, @region, @required_points, @latitude, @longitude,
  @image, @thumbnail, @original_image, @original_width, @original_height, @active,
  @tip_en, @tip_es,
  @tip_normal_en, @tip_normal_es, @tip_hard_en, @tip_hard_es, @tip_expert_en, @tip_expert_es,
  @crop_x, @crop_y, @crop_w, @crop_h,
  @crop_easy_x, @crop_easy_y, @crop_easy_w, @crop_easy_h,
  @crop_normal_x, @crop_normal_y, @crop_normal_w, @crop_normal_h,
  @crop_hard_x, @crop_hard_y, @crop_hard_w, @crop_hard_h,
  @crop_expert_x, @crop_expert_y, @crop_expert_w, @crop_expert_h,
  @difficulty
`;
const insertLocationStmt = db.prepare(`INSERT INTO locations (${LOCATION_INSERT_COLS}) VALUES (${LOCATION_INSERT_VALS})`);

// CREATE location
app.post('/api/locations', (req, res) => {
  const obj = req.body;
  if (!obj.id) return res.status(400).json({ error: 'Missing id' });

  const params = locationToParams(obj);
  try {
    insertLocationStmt.run(params);
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
      original_image = @original_image, original_width = @original_width, original_height = @original_height,
      active = @active,
      tip_en = @tip_en, tip_es = @tip_es,
      tip_normal_en = @tip_normal_en, tip_normal_es = @tip_normal_es,
      tip_hard_en = @tip_hard_en, tip_hard_es = @tip_hard_es,
      tip_expert_en = @tip_expert_en, tip_expert_es = @tip_expert_es,
      crop_x = @crop_x, crop_y = @crop_y, crop_w = @crop_w, crop_h = @crop_h,
      crop_easy_x = @crop_easy_x, crop_easy_y = @crop_easy_y, crop_easy_w = @crop_easy_w, crop_easy_h = @crop_easy_h,
      crop_normal_x = @crop_normal_x, crop_normal_y = @crop_normal_y, crop_normal_w = @crop_normal_w, crop_normal_h = @crop_normal_h,
      crop_hard_x = @crop_hard_x, crop_hard_y = @crop_hard_y, crop_hard_w = @crop_hard_w, crop_hard_h = @crop_hard_h,
      crop_expert_x = @crop_expert_x, crop_expert_y = @crop_expert_y, crop_expert_w = @crop_expert_w, crop_expert_h = @crop_expert_h,
      difficulty = @difficulty, updated_at = @updated_at
    WHERE id = @id
  `).run(params);

  if (result.changes === 0) return res.status(404).json({ error: 'Not found' });
  res.json({ success: true });
});

// BATCH STUB — create N inactive locations from upload results in one shot.
// Body: { uploads: [{ url, thumbnail, original, width, height }, ...] }
app.post('/api/locations/batch-stub', (req, res) => {
  const uploads = Array.isArray(req.body?.uploads) ? req.body.uploads : null;
  if (!uploads || uploads.length === 0) {
    return res.status(400).json({ error: 'Expected uploads: [...]' });
  }
  const ts = Date.now();
  const ids = [];
  const tx = db.transaction(() => {
    uploads.forEach((u, i) => {
      const id = `loc_${ts}_${i}`;
      ids.push(id);
      insertLocationStmt.run(locationToParams({
        id,
        // Sentinels avoid NOT NULL constraint without schema changes.
        // Admin form clears them on focus so they don't contaminate real data.
        name: { en: '—', es: '—' },
        region: '—',
        requiredPoints: 0,
        latitude: 0,
        longitude: 0,
        image: u.url || '',
        thumbnail: u.thumbnail || u.url || '',
        originalImage: u.original || '',
        originalWidth: u.width || 0,
        originalHeight: u.height || 0,
        active: false,
        tip: { en: '', es: '' },
        tipsByDifficulty: {},
        crop: { x: 0.15, y: 0.15, w: 0.7, h: 0.7 },
        cropsByDifficulty: {
          '3': { x: 0, y: 0, w: 1, h: 1 },
          '4': { x: 0, y: 0, w: 1, h: 1 },
          '5': { x: 0.05, y: 0.05, w: 0.9, h: 0.9 },
          '6': { x: 0.15, y: 0.15, w: 0.7, h: 0.7 },
        },
        difficulty: [3, 4, 5, 6],
      }));
    });
  });
  try {
    tx();
    const rows = db.prepare(
      `SELECT * FROM locations WHERE id IN (${ids.map((_, i) => `@id${i}`).join(',')})`
    ).all(Object.fromEntries(ids.map((id, i) => [`id${i}`, id])));
    res.json({ ids, rows: rows.map(rowToLocation) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
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
      move_efficiency_bonus_pct = @meb,
      tester_spots = @ts
    WHERE id = 1
  `).run({
    bp3: s.basePoints?.['3'] ?? 50,
    bp4: s.basePoints?.['4'] ?? 100,
    bp5: s.basePoints?.['5'] ?? 200,
    bp6: s.basePoints?.['6'] ?? 350,
    tbt: s.timeBonusThresholdSecs ?? 60,
    tbp: s.timeBonusPoints ?? 50,
    meb: s.moveEfficiencyBonusPercent ?? 20,
    ts: s.testerSpots ?? 100,
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

    // Read dimensions from the original upload so the admin can warn
    // when a crop would be too small to render crisply fullscreen.
    // EXIF orientations 5-8 indicate 90°/270° rotation → swap W/H so the
    // values match the rotated output we actually serve to clients.
    let meta = { width: 0, height: 0 };
    try {
      const raw = await sharp(req.file.path).metadata();
      const o = raw.orientation || 1;
      meta = (o >= 5 && o <= 8)
        ? { width: raw.height || 0, height: raw.width || 0 }
        : { width: raw.width || 0, height: raw.height || 0 };
    } catch (_) {}

    // Preserve the untouched original (same extension as upload) for future re-crops.
    const origExt = path.extname(req.file.originalname).toLowerCase() || '.jpg';
    const origName = baseName + '_orig' + origExt;
    const origPath = path.join(uploadsDir, origName);
    fs.copyFileSync(req.file.path, origPath);

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

    // Clean up temp upload
    fs.unlinkSync(req.file.path);

    const fullName = baseName + '.jpg';
    res.json({
      url: `${URL_PREFIX}/uploads/${fullName}`,
      thumbnail: `${URL_PREFIX}/uploads/${thumbName}`,
      original: `${URL_PREFIX}/uploads/${origName}`,
      width: meta.width || 0,
      height: meta.height || 0,
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
      original: `${URL_PREFIX}/uploads/${fallbackName}`,
      width: 0,
      height: 0,
    });
  }
});

// Batch generate thumbnails for existing locations
app.post('/api/generate-thumbnails', async (req, res) => {
  const force = req.query.force === '1';
  const query = force
    ? 'SELECT id, image, thumbnail FROM locations'
    : 'SELECT id, image, thumbnail FROM locations WHERE thumbnail = image';
  const rows = db.prepare(query).all();
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
        .rotate()
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
  const { locationId, difficulty } = req.query;

  // Per-location branch
  if (locationId && difficulty != null) {
    const diff = parseInt(difficulty, 10);
    const rows = db.prepare(`
      SELECT initials, points, time_seconds, moves, created_at
      FROM location_leaderboard
      WHERE location_id = ? AND difficulty = ?
      ORDER BY points DESC, time_seconds ASC, created_at ASC
      LIMIT 25
    `).all(locationId, diff);

    const entries = rows.map((row, i) => ({
      rank: i + 1,
      initials: row.initials,
      points: row.points,
      totalPoints: row.points, // duplicate for reuse of global row widget
      timeSeconds: row.time_seconds,
      moves: row.moves,
      createdAt: row.created_at,
    }));
    const qualifyingScore = rows.length >= 25 ? rows[24].points : 0;
    return res.json({ entries, qualifyingScore });
  }

  // Global branch (existing)
  const limit = Math.min(parseInt(req.query.limit) || 50, 200);
  const rows = db.prepare(`
    SELECT id, initials, total_points, puzzles_completed, time_seconds, moves, created_at
    FROM leaderboard ORDER BY total_points DESC, time_seconds ASC, created_at DESC
    LIMIT ?
  `).all(limit);

  const entries = rows.map((row, i) => ({
    rank: i + 1,
    initials: row.initials,
    totalPoints: row.total_points,
    puzzlesCompleted: row.puzzles_completed,
    timeSeconds: row.time_seconds,
    moves: row.moves,
    createdAt: row.created_at,
  }));

  res.json({ entries });
});

app.post('/api/leaderboard', (req, res) => {
  const { initials, locationId, difficulty, points, totalPoints, puzzlesCompleted, timeSeconds, moves } = req.body;

  if (!initials || !/^[A-Z]{3}$/.test(initials)) {
    return res.status(400).json({ error: 'Initials must be exactly 3 uppercase letters' });
  }
  if (BANNED_INITIALS.length && BANNED_INITIALS.includes(initials)) {
    return res.status(400).json({ error: 'Invalid initials' });
  }

  // Per-location branch
  if (locationId && difficulty != null && typeof points === 'number') {
    if (points < 0) return res.status(400).json({ error: 'Invalid points' });
    const diff = parseInt(difficulty, 10);

    db.prepare(`
      INSERT INTO location_leaderboard (location_id, difficulty, initials, points, time_seconds, moves)
      VALUES (@locationId, @difficulty, @initials, @points, @timeSeconds, @moves)
      ON CONFLICT(location_id, difficulty, initials) DO UPDATE SET
        points = excluded.points,
        time_seconds = excluded.time_seconds,
        moves = excluded.moves,
        created_at = datetime('now')
      WHERE excluded.points > location_leaderboard.points
    `).run({
      locationId,
      difficulty: diff,
      initials,
      points,
      timeSeconds: timeSeconds || 0,
      moves: moves || 0,
    });

    // Prune beyond top 25
    db.prepare(`
      DELETE FROM location_leaderboard
      WHERE location_id = ? AND difficulty = ?
        AND id NOT IN (
          SELECT id FROM location_leaderboard
          WHERE location_id = ? AND difficulty = ?
          ORDER BY points DESC, time_seconds ASC
          LIMIT 25
        )
    `).run(locationId, diff, locationId, diff);

    // Compute rank (or null if pruned)
    const rankRow = db.prepare(`
      SELECT rank FROM (
        SELECT initials, ROW_NUMBER() OVER (ORDER BY points DESC, time_seconds ASC) AS rank
        FROM location_leaderboard
        WHERE location_id = ? AND difficulty = ?
      ) WHERE initials = ?
    `).get(locationId, diff, initials);

    return res.json({ rank: rankRow?.rank ?? null });
  }

  // Global branch (existing)
  if (typeof totalPoints !== 'number' || totalPoints < 0) {
    return res.status(400).json({ error: 'Invalid totalPoints' });
  }

  const result = db.prepare(`
    INSERT INTO leaderboard (initials, total_points, puzzles_completed, time_seconds, moves)
    VALUES (@initials, @totalPoints, @puzzlesCompleted, @timeSeconds, @moves)
  `).run({
    initials,
    totalPoints: totalPoints || 0,
    puzzlesCompleted: puzzlesCompleted || 0,
    timeSeconds: timeSeconds || 0,
    moves: moves || 0,
  });

  // Calculate rank
  const rank = db.prepare(`
    SELECT COUNT(*) + 1 as rank FROM leaderboard
    WHERE total_points > @points OR (total_points = @points AND time_seconds < @time)
  `).get({ points: totalPoints || 0, time: timeSeconds || 0 }).rank;

  res.json({ id: result.lastInsertRowid, rank });
});

// ============================================================
// TESTERS
// ============================================================
app.get('/api/tester-spots', (req, res) => {
  const row = db.prepare('SELECT tester_spots FROM scoring WHERE id = 1').get();
  const total = db.prepare('SELECT COUNT(*) as count FROM testers').get();
  res.json({ spots: row?.tester_spots ?? 100, registered: total.count });
});

app.post('/api/testers', async (req, res) => {
  const { name, email, lang, platform } = req.body;
  if (!name || !email) return res.status(400).json({ error: 'Name and email required' });
  const cleanEmail = email.trim().toLowerCase();
  const cleanLang = (lang || 'es').substring(0, 2);
  const cleanPlatform = (platform === 'ios') ? 'ios' : 'android';

  const existing = db.prepare('SELECT id FROM testers WHERE email = ?').get(cleanEmail);
  if (existing) return res.json({ ok: true, message: 'Already registered' });

  const result = db.prepare(
    'INSERT INTO testers (name, email, lang, platform) VALUES (?, ?, ?, ?)'
  ).run(name.trim(), cleanEmail, cleanLang, cleanPlatform);

  // Notify admin about new tester
  const BREVO_KEY = process.env.BREVO_API_KEY;
  if (BREVO_KEY) {
    try {
      await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: { 'accept': 'application/json', 'api-key': BREVO_KEY, 'content-type': 'application/json' },
        body: JSON.stringify({
          sender: { name: 'Zoom-In Chile', email: 'no-reply@sabino.cl' },
          to: [{ email: 'sabinovelasquez@gmail.com', name: 'Sabino' }],
          subject: `Nuevo tester: ${name.trim()} (${cleanPlatform})`,
          htmlContent: `<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:2rem;">
            <h2 style="color:#1565C0;">Nuevo Tester</h2>
            <p><strong>Nombre:</strong> ${name.trim()}</p>
            <p><strong>Email:</strong> ${cleanEmail}</p>
            <p><strong>Plataforma:</strong> ${cleanPlatform}</p>
            <p><strong>Idioma:</strong> ${cleanLang.toUpperCase()}</p>
          </div>`,
        }),
      });
    } catch (_) { /* don't block signup if notification fails */ }
  }

  res.json({ ok: true, id: result.lastInsertRowid });
});

app.get('/api/testers', (req, res) => {
  const rows = db.prepare('SELECT * FROM testers ORDER BY created_at DESC').all();
  res.json(rows.map(rowToTester));
});

app.put('/api/testers/:id', (req, res) => {
  const { enrolled } = req.body;
  db.prepare('UPDATE testers SET enrolled = ? WHERE id = ?').run(enrolled ? 1 : 0, req.params.id);
  res.json({ ok: true });
});

app.delete('/api/testers/:id', (req, res) => {
  db.prepare('DELETE FROM testers WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

app.post('/api/testers/notify', async (req, res) => {
  const BREVO_KEY = process.env.BREVO_API_KEY;
  if (!BREVO_KEY) return res.status(500).json({ error: 'Brevo API key not configured' });

  const downloadUrl = 'https://play.google.com/apps/internaltest/4700433915880246135';
  const defaultSubject = 'Zoom-In Chile - Early Access';
  const defaultHtmlEs = `<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:2rem;">
    <h2 style="color:#1565C0;">Zoom-In Chile</h2>
    <p>Hola {{name}},</p>
    <p>La app ya está disponible para testing. Descárgala aquí:</p>
    <p><a href="${downloadUrl}" style="display:inline-block;padding:12px 24px;background:#1565C0;color:white;text-decoration:none;border-radius:8px;font-weight:600;">Descargar App</a></p>
    <p style="color:#888;font-size:0.85rem;">Gracias por ser parte de los primeros testers.</p>
  </div>`;
  const defaultHtmlEn = `<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:2rem;">
    <h2 style="color:#1565C0;">Zoom-In Chile</h2>
    <p>Hi {{name}},</p>
    <p>The app is now available for testing. Download it here:</p>
    <p><a href="${downloadUrl}" style="display:inline-block;padding:12px 24px;background:#1565C0;color:white;text-decoration:none;border-radius:8px;font-weight:600;">Download App</a></p>
    <p style="color:#888;font-size:0.85rem;">Thanks for being one of our early testers.</p>
  </div>`;

  const subject = (req.body && req.body.subject) || defaultSubject;
  const htmlEs = (req.body && req.body.htmlEs) || defaultHtmlEs;
  const htmlEn = (req.body && req.body.htmlEn) || defaultHtmlEn;

  const testers = db.prepare('SELECT * FROM testers WHERE enrolled = 1 AND notified = 0').all();
  if (testers.length === 0) return res.json({ ok: true, sent: 0, message: 'No testers to notify' });

  let sent = 0;
  const errors = [];

  for (const tester of testers) {
    const html = (tester.lang === 'en' ? htmlEn : htmlEs).replace(/\{\{name\}\}/g, tester.name);
    try {
      const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'accept': 'application/json',
          'api-key': BREVO_KEY,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          sender: { name: 'Zoom-In Chile', email: 'no-reply@sabino.cl' },
          to: [{ email: tester.email, name: tester.name }],
          subject,
          htmlContent: html,
        }),
      });
      if (response.ok) {
        db.prepare('UPDATE testers SET notified = 1 WHERE id = ?').run(tester.id);
        sent++;
      } else {
        const err = await response.text();
        errors.push({ email: tester.email, error: err });
      }
    } catch (e) {
      errors.push({ email: tester.email, error: e.message });
    }
  }

  res.json({ ok: true, sent, total: testers.length, errors: errors.length > 0 ? errors : undefined });
});

app.post('/api/testers/:id/notify', async (req, res) => {
  const BREVO_KEY = process.env.BREVO_API_KEY;
  if (!BREVO_KEY) return res.status(500).json({ error: 'Brevo API key not configured' });

  const tester = db.prepare('SELECT * FROM testers WHERE id = ?').get(req.params.id);
  if (!tester) return res.status(404).json({ error: 'Tester not found' });

  const lang = (req.body && req.body.lang) || tester.lang || 'es';
  const downloadUrl = 'https://play.google.com/apps/internaltest/4700433915880246135';
  const templates = {
    es: `<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:2rem;">
      <h2 style="color:#1565C0;">Zoom-In Chile</h2>
      <p>Hola {{name}},</p>
      <p>La app ya está disponible para testing. Descárgala aquí:</p>
      <p><a href="${downloadUrl}" style="display:inline-block;padding:12px 24px;background:#1565C0;color:white;text-decoration:none;border-radius:8px;font-weight:600;">Descargar App</a></p>
      <p style="color:#888;font-size:0.85rem;">Gracias por ser parte de los primeros testers.</p>
    </div>`,
    en: `<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:2rem;">
      <h2 style="color:#1565C0;">Zoom-In Chile</h2>
      <p>Hi {{name}},</p>
      <p>The app is now available for testing. Download it here:</p>
      <p><a href="${downloadUrl}" style="display:inline-block;padding:12px 24px;background:#1565C0;color:white;text-decoration:none;border-radius:8px;font-weight:600;">Download App</a></p>
      <p style="color:#888;font-size:0.85rem;">Thanks for being one of our early testers.</p>
    </div>`,
  };

  const html = (templates[lang] || templates.es).replace(/\{\{name\}\}/g, tester.name);
  try {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'accept': 'application/json', 'api-key': BREVO_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({
        sender: { name: 'Zoom-In Chile', email: 'no-reply@sabino.cl' },
        to: [{ email: tester.email, name: tester.name }],
        subject: 'Zoom-In Chile - Early Access',
        htmlContent: html,
      }),
    });
    if (response.ok) {
      db.prepare('UPDATE testers SET notified = 1 WHERE id = ?').run(tester.id);
      res.json({ ok: true });
    } else {
      const err = await response.text();
      res.status(500).json({ error: err });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============================================================
// START
// ============================================================
app.listen(PORT, BIND, () => {
  console.log(`✨ Admin server running at http://${BIND}:${PORT}${URL_PREFIX}`);
});
