require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const sharp = require('sharp');
const { db, rowToLocation, locationToParams, rowToZone, rowToTrophy, rowToScoring, rowToTester, rowToRelease } = require('./db');
const { renderDownloadEmail, renderReleaseEmail, renderProgressBackupEmail } = require('./email-templates');
const { readChangelogEntry } = require('./changelog');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const cheerio = require('cheerio');

const app = express();
const PORT = process.env.PORT || 3000;
const BIND = process.env.BIND || '0.0.0.0';
const URL_PREFIX = process.env.URL_PREFIX || '';
const uploadsDir = path.join(__dirname, 'public', 'uploads');
const upload = multer({ dest: uploadsDir });

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

async function writeStats() {
  const { n } = db.prepare('SELECT COUNT(*) as n FROM locations WHERE active = 1').get();
  const stats = { activeLocations: n, updatedAt: new Date().toISOString() };
  await fs.promises.writeFile(
    path.join(__dirname, 'public', 'stats.json'),
    JSON.stringify(stats),
  );
}

// ============================================================
// EMAIL HELPER (Brevo)
// ============================================================
async function sendBrevoEmail({ to, subject, htmlContent }) {
  const BREVO_KEY = process.env.BREVO_API_KEY;
  if (!BREVO_KEY) throw new Error('Brevo API key not configured');
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'accept': 'application/json',
      'api-key': BREVO_KEY,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      sender: { name: 'Zoom-In Chile', email: 'no-reply@sabino.cl' },
      to,
      subject,
      htmlContent,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(err);
  }
  return res;
}

// ============================================================
// STATS — lightweight public endpoint for landing page
// ============================================================
app.get('/api/stats', (req, res) => {
  const { n } = db.prepare('SELECT COUNT(*) as n FROM locations WHERE active = 1').get();
  res.json({ activeLocations: n, updatedAt: new Date().toISOString() });
});

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
  image, thumbnail, original_image, original_width, original_height, rotation_deg, active,
  show_silhouette_d3, show_silhouette_d4, show_silhouette_d5, show_silhouette_d6,
  tip_en, tip_es,
  tip_normal_en, tip_normal_es, tip_hard_en, tip_hard_es, tip_expert_en, tip_expert_es,
  crop_x, crop_y, crop_w, crop_h,
  crop_easy_x, crop_easy_y, crop_easy_w, crop_easy_h,
  crop_normal_x, crop_normal_y, crop_normal_w, crop_normal_h,
  crop_hard_x, crop_hard_y, crop_hard_w, crop_hard_h,
  crop_expert_x, crop_expert_y, crop_expert_w, crop_expert_h,
  image_d3, image_d4, image_d5, image_d6,
  difficulty
`;
const LOCATION_INSERT_VALS = `
  @id, @name_en, @name_es, @region, @required_points, @latitude, @longitude,
  @image, @thumbnail, @original_image, @original_width, @original_height, @rotation_deg, @active,
  @show_silhouette_d3, @show_silhouette_d4, @show_silhouette_d5, @show_silhouette_d6,
  @tip_en, @tip_es,
  @tip_normal_en, @tip_normal_es, @tip_hard_en, @tip_hard_es, @tip_expert_en, @tip_expert_es,
  @crop_x, @crop_y, @crop_w, @crop_h,
  @crop_easy_x, @crop_easy_y, @crop_easy_w, @crop_easy_h,
  @crop_normal_x, @crop_normal_y, @crop_normal_w, @crop_normal_h,
  @crop_hard_x, @crop_hard_y, @crop_hard_w, @crop_hard_h,
  @crop_expert_x, @crop_expert_y, @crop_expert_w, @crop_expert_h,
  @image_d3, @image_d4, @image_d5, @image_d6,
  @difficulty
`;
const insertLocationStmt = db.prepare(`INSERT INTO locations (${LOCATION_INSERT_COLS}) VALUES (${LOCATION_INSERT_VALS})`);

// Helpers for detecting crop/rotation changes (triggers per-diff re-render on save).
const CROP_COLS = [
  'crop_easy_x','crop_easy_y','crop_easy_w','crop_easy_h',
  'crop_normal_x','crop_normal_y','crop_normal_w','crop_normal_h',
  'crop_hard_x','crop_hard_y','crop_hard_w','crop_hard_h',
  'crop_expert_x','crop_expert_y','crop_expert_w','crop_expert_h',
];
function cropsDiffer(rowA, rowB) {
  if (!rowA || !rowB) return true;
  if (Math.abs((rowA.rotation_deg || 0) - (rowB.rotation_deg || 0)) > 1e-9) return true;
  return CROP_COLS.some(c => Math.abs((rowA[c] || 0) - (rowB[c] || 0)) > 1e-9);
}
async function regenerateAndUpdateImages(id) {
  const row = db.prepare('SELECT * FROM locations WHERE id = ?').get(id);
  if (!row) return null;
  const loc = rowToLocation(row);
  const results = await renderPerDiffCrops(loc);
  if (!results) return null;

  // Regenerate thumbnail with the same rotation so the card cover matches.
  const origPath = loc.originalImage ? path.join(uploadsDir, path.basename(loc.originalImage)) : null;
  const fallbackPath = loc.image ? path.join(uploadsDir, path.basename(loc.image)) : null;
  const sourcePath = (origPath && fs.existsSync(origPath)) ? origPath
    : (fallbackPath && fs.existsSync(fallbackPath) ? fallbackPath : null);
  if (sourcePath) {
    try {
      const baseName = path.basename(loc.image || sourcePath).replace(/\.[^.]+$/, '');
      const thumbName = `${baseName}_thumb.jpg`;
      const thumbPath = path.join(uploadsDir, thumbName);
      let pipeline = sharp(sourcePath).rotate();
      if (loc.rotationDeg) pipeline = pipeline.rotate(loc.rotationDeg, { background: { r: 0, g: 0, b: 0 } });
      await pipeline.resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 70 }).toFile(thumbPath);
      results.thumbnail = `${URL_PREFIX}/uploads/${thumbName}`;
    } catch (_) {}
  }

  db.prepare(`
    UPDATE locations
    SET image_d3 = @image_d3, image_d4 = @image_d4, image_d5 = @image_d5, image_d6 = @image_d6
      ${results.thumbnail ? ', thumbnail = @thumbnail' : ''}
    WHERE id = @id
  `).run({ id, ...results });
  return results;
}

// CREATE location
app.post('/api/locations', async (req, res) => {
  const obj = req.body;
  if (!obj.id) return res.status(400).json({ error: 'Missing id' });

  const params = locationToParams(obj);
  try {
    insertLocationStmt.run(params);
    // If the caller included an original image + per-diff crops, render them now
    // so the new record is immediately playable on new Flutter clients.
    if (params.original_image) {
      try { await regenerateAndUpdateImages(obj.id); }
      catch (e) { console.error('renderPerDiffCrops (POST) failed:', e.message); }
    }
    writeStats().catch(() => {});
    res.json({ success: true, id: obj.id });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// UPDATE location
app.put('/api/locations/:id', async (req, res) => {
  const obj = { ...req.body, id: req.params.id };
  const params = locationToParams(obj);
  params.updated_at = new Date().toISOString().replace('T', ' ').slice(0, 19);

  // Read the stored crops BEFORE the update so we can decide whether to re-render.
  const before = db.prepare('SELECT * FROM locations WHERE id = ?').get(req.params.id);

  const result = db.prepare(`
    UPDATE locations SET
      name_en = @name_en, name_es = @name_es, region = @region,
      required_points = @required_points, latitude = @latitude, longitude = @longitude,
      image = @image, thumbnail = @thumbnail,
      original_image = @original_image, original_width = @original_width, original_height = @original_height,
      rotation_deg = @rotation_deg,
      active = @active,
      show_silhouette_d3 = @show_silhouette_d3, show_silhouette_d4 = @show_silhouette_d4,
      show_silhouette_d5 = @show_silhouette_d5, show_silhouette_d6 = @show_silhouette_d6,
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

  // Re-render per-difficulty images when crops/rotation changed or none exist yet.
  // renderPerDiffCrops handles source selection (_orig → loc.image fallback),
  // so we don't gate on params.original_image here anymore.
  let rendered = false;
  const noneYet = !before?.image_d3 && !before?.image_d4 && !before?.image_d5 && !before?.image_d6;
  if (cropsDiffer(before, params) || noneYet) {
    try {
      await regenerateAndUpdateImages(req.params.id);
      rendered = true;
    } catch (e) {
      console.error('renderPerDiffCrops (PUT) failed:', e.message);
    }
  }
  writeStats().catch(() => {});
  res.json({ success: true, rendered });
});

// BATCH STUB — create N inactive locations from upload results in one shot.
// Body: { uploads: [{ url, thumbnail, original, width, height }, ...] }
app.post('/api/locations/batch-stub', async (req, res) => {
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
        latitude: u.gps?.lat || 0,
        longitude: u.gps?.lng || 0,
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
    // Render per-difficulty crops for each new stub so they're immediately
    // playable on Flutter clients that consume imagesByDifficulty.
    for (const id of ids) {
      try { await regenerateAndUpdateImages(id); }
      catch (e) { console.error(`renderPerDiffCrops (batch-stub ${id}) failed:`, e.message); }
    }
    const rows = db.prepare(
      `SELECT * FROM locations WHERE id IN (${ids.map((_, i) => `@id${i}`).join(',')})`
    ).all(Object.fromEntries(ids.map((id, i) => [`id${i}`, id])));
    writeStats().catch(() => {});
    res.json({ ids, rows: rows.map(rowToLocation) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// DELETE location — also removes all associated image files from disk.
app.delete('/api/locations/:id', (req, res) => {
  const row = db.prepare(
    'SELECT image, thumbnail, original_image, image_d3, image_d4, image_d5, image_d6 FROM locations WHERE id = ?'
  ).get(req.params.id);
  if (!row) return res.status(404).json({ error: 'Not found' });

  const result = db.prepare('DELETE FROM locations WHERE id = @id').run({ id: req.params.id });
  if (result.changes === 0) return res.status(404).json({ error: 'Not found' });

  // Delete every file associated with this location. Deduplicate in case image === thumbnail.
  const seen = new Set();
  for (const url of [row.image, row.thumbnail, row.original_image, row.image_d3, row.image_d4, row.image_d5, row.image_d6]) {
    if (!url) continue;
    const fname = url.split('/').pop();
    if (seen.has(fname)) continue;
    seen.add(fname);
    try { fs.unlinkSync(path.join(uploadsDir, fname)); } catch (_) {}
  }
  writeStats().catch(() => {});
  res.json({ success: true });
});

// DELETE the raw original file for a location (space reclaim).
// The per-difficulty pre-rendered images stay intact; re-cropping later
// requires a fresh upload. original_width/height stay for reference.
app.delete('/api/locations/:id/original', (req, res) => {
  const row = db.prepare('SELECT original_image FROM locations WHERE id = ?')
                .get(req.params.id);
  if (!row) return res.status(404).json({ error: 'Not found' });
  if (!row.original_image) return res.json({ success: true, alreadyEmpty: true });

  const filePath = path.join(uploadsDir, path.basename(row.original_image));
  try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (_) {}
  db.prepare("UPDATE locations SET original_image = '' WHERE id = ?")
    .run(req.params.id);
  res.json({ success: true });
});

// Force-regenerate per-difficulty crops for a single location, regardless of
// whether crops have changed. Useful to apply new server-side render fixes.
app.post('/api/locations/:id/regenerate', async (req, res) => {
  try {
    const out = await regenerateAndUpdateImages(req.params.id);
    if (!out) return res.status(404).json({ error: 'No source file found or location missing' });
    res.json({ success: true, ...out });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Bulk regenerate per-difficulty crops for all locations. Idempotent — safe
// to rerun. Uses _orig when available, falls back to loc.image for legacy.
app.post('/api/regenerate-crops', async (req, res) => {
  const rows = db.prepare("SELECT id FROM locations WHERE image != ''").all();
  const results = { total: rows.length, rendered: [], skipped: [], errors: [] };
  for (const row of rows) {
    try {
      const out = await regenerateAndUpdateImages(row.id);
      if (out) results.rendered.push(row.id);
      else results.skipped.push(row.id);
    } catch (e) {
      console.error('regenerate-crops failed for', row.id, e.message);
      results.errors.push({ id: row.id, error: e.message });
    }
  }
  res.json(results);
});

// ── AI tip generation ──────────────────────────────────────────
async function extractTextFromUrl(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; ChilePuzzleAdmin/1.0)' },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const html = await res.text();
    const $ = cheerio.load(html);
    $('script, style, nav, footer, header, aside, iframe, noscript').remove();
    const main = $('main, article, .content, .mw-parser-output, #bodyContent').first();
    const text = (main.length ? main : $('body')).text();
    return text.replace(/\s+/g, ' ').trim().slice(0, 8000);
  } finally {
    clearTimeout(timeout);
  }
}

function buildTipPrompt(locationName, description, referenceText) {
  const hasDesc = description && description.trim().length > 0;
  const hasRef = referenceText && referenceText.trim().length > 0;
  return `You are a concise tourism fact writer for a Chilean locations puzzle game.

Given the location name${hasDesc || hasRef ? ' and context' : ''} below, generate exactly 3 tips in both Spanish (ES) and English (EN).${!hasDesc && !hasRef ? ' Use your own knowledge about this Chilean location.' : ''}

LOCATION: "${locationName}"
${hasDesc ? `\nPHOTO DESCRIPTION (primary context — this describes what the player sees in the puzzle photo):\n${description.trim()}` : ''}
${hasRef ? `\nREFERENCE MATERIAL (supplementary):\n${referenceText}` : ''}

RULES:
- Each tip MUST be under 200 characters (this is a hard limit — count carefully).
- Write in a factual, informative tone — no exclamation marks, no "Did you know?", no filler words.
- Tips are shown as hints to help players identify a photo of this location.
- Each tip reveals progressively more specific/obscure information.
- EASY (Dato Físico/Geográfico): What it is, where it is located, and its primary function. General knowledge a tourist would know.
- NORMAL (Dato Histórico/Constructivo): Year of origin, architect/designer, specific materials, or a key historical event tied to it.
- HARD (Dato Técnico/Curiosidad): Precise dimensions, conservation status, a structural or engineering detail, or a little-known fact.

OUTPUT FORMAT — respond with ONLY this JSON, no markdown fences, no commentary:
{
  "easy":   { "es": "...", "en": "..." },
  "normal": { "es": "...", "en": "..." },
  "hard":   { "es": "...", "en": "..." }
}`;
}

function parseTipResponse(text) {
  const cleaned = text.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim();
  const match = cleaned.match(/\{[\s\S]*\}/);
  if (!match) throw new Error('Could not parse AI response as JSON');
  const tips = JSON.parse(match[0]);
  for (const level of ['easy', 'normal', 'hard']) {
    if (!tips[level]?.es || !tips[level]?.en) {
      throw new Error(`Missing ${level} tip in AI response`);
    }
    for (const lang of ['es', 'en']) {
      if (tips[level][lang].length > 200) {
        const truncated = tips[level][lang].slice(0, 197);
        tips[level][lang] = truncated.slice(0, truncated.lastIndexOf(' ')) + '...';
      }
    }
  }
  return tips;
}

app.post('/api/locations/process', async (req, res) => {
  const { locationName, links = [], description } = req.body;
  if (!locationName) {
    return res.status(400).json({ error: 'locationName is required' });
  }
  if (links.length === 0 && !description?.trim()) {
    return res.status(400).json({ error: 'Provide at least one link or a description' });
  }
  if (links.length > 5) {
    return res.status(400).json({ error: 'Maximum 5 links allowed' });
  }
  if (!process.env.GEMINI_API_KEY) {
    return res.status(500).json({ error: 'Gemini API key not configured on server' });
  }
  try {
    let referenceText = '';
    if (links.length > 0) {
      const results = await Promise.allSettled(links.map(extractTextFromUrl));
      const texts = results.filter(r => r.status === 'fulfilled' && r.value).map(r => r.value);
      referenceText = texts.join('\n\n---\n\n');
    }
    const prompt = buildTipPrompt(locationName, description || '', referenceText);
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
    const result = await model.generateContent(prompt);
    const tips = parseTipResponse(result.response.text());
    res.json({ tips });
  } catch (e) {
    console.error('process-location failed:', e);
    res.status(500).json({ error: e.message || 'AI processing failed' });
  }
});

app.post('/api/translate', async (req, res) => {
  const { text, from = 'es', to = 'en' } = req.body;
  if (!text?.trim()) return res.status(400).json({ error: 'text is required' });
  if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: 'Gemini API key not configured' });
  try {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
    const prompt = `Translate the following text from ${from === 'es' ? 'Spanish' : 'English'} to ${to === 'en' ? 'English' : 'Spanish'}. Keep the same tone and length. Respond with ONLY the translated text, nothing else.\n\n${text.trim()}`;
    const result = await model.generateContent(prompt);
    res.json({ translated: result.response.text().trim() });
  } catch (e) {
    console.error('translate failed:', e);
    res.status(500).json({ error: e.message || 'Translation failed' });
  }
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

    // Try to extract GPS coordinates from EXIF (works with JPEG, HEIC, TIFF).
    // Google Photos exports may have NaN values — isFinite() guards against that.
    let gps = null;
    try {
      const exifr = require('exifr');
      const parsed = await exifr.parse(req.file.path, true);
      if (parsed && isFinite(parsed.latitude) && isFinite(parsed.longitude)) {
        gps = { lat: parsed.latitude, lng: parsed.longitude };
      }
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
      .jpeg({ quality: 95 })
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
      gps,
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

// Renders 4 per-difficulty cropped JPEGs from the raw original file on disk.
// Returns { image_d3, image_d4, image_d5, image_d6 } URL paths, or null if no
// usable source file exists. Prefers _orig; falls back to loc.image for legacy
// locations that were uploaded before _orig tracking was added.
async function renderPerDiffCrops(loc) {
  const origPath = loc.originalImage
    ? path.join(uploadsDir, path.basename(loc.originalImage))
    : null;
  const fallbackPath = loc.image
    ? path.join(uploadsDir, path.basename(loc.image))
    : null;
  const sourcePath = (origPath && fs.existsSync(origPath))
    ? origPath
    : (fallbackPath && fs.existsSync(fallbackPath) ? fallbackPath : null);
  if (!sourcePath) return null;

  // Read EXIF-corrected dimensions (swap W/H for orientations 5-8).
  const rawMeta = await sharp(sourcePath).metadata();
  const o = rawMeta.orientation || 1;
  const exifW = (o >= 5 && o <= 8) ? (rawMeta.height || 0) : (rawMeta.width || 0);
  const exifH = (o >= 5 && o <= 8) ? (rawMeta.width || 0)  : (rawMeta.height || 0);
  if (!exifW || !exifH) return null;

  // If a user rotation is set, crop coords are relative to the rotated bounding box.
  const rotDeg = loc.rotationDeg || 0;
  const θ = rotDeg * Math.PI / 180;
  const cosA = Math.abs(Math.cos(θ)), sinA = Math.abs(Math.sin(θ));
  const bbW = exifW * cosA + exifH * sinA;
  const bbH = exifW * sinA + exifH * cosA;

  const baseName = path.basename(loc.image || sourcePath).replace(/\.[^.]+$/, '');
  const results = {};
  for (const diff of ['3', '4', '5', '6']) {
    const c = loc.cropsByDifficulty?.[diff];
    if (!c) continue;
    let left   = Math.max(0, Math.min(bbW - 1, Math.round(c.x * bbW)));
    let top    = Math.max(0, Math.min(bbH - 1, Math.round(c.y * bbH)));
    let width  = Math.max(1, Math.min(bbW - left, Math.round(c.w * bbW)));
    let height = Math.max(1, Math.min(bbH - top,  Math.round(c.h * bbH)));
    // _d3 is the photo-viewer image and must always be portrait. If the crop
    // would produce landscape (e.g. default full-image crop on a landscape photo),
    // auto-correct by center-cropping to 9:16 within the selected region.
    if (diff === '3' && width > height) {
      const portraitW = Math.round(height * 9 / 16);
      left  = left + Math.round((width - portraitW) / 2);
      width = portraitW;
    }
    const outName = `${baseName}_d${diff}.jpg`;
    const outPath = path.join(uploadsDir, outName);
    let pipeline = sharp(sourcePath).rotate();           // honor EXIF orientation
    if (rotDeg) pipeline = pipeline.rotate(rotDeg, { background: { r: 0, g: 0, b: 0 } });
    await pipeline
      .extract({ left, top, width, height })
      .resize(3000, 3000, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 95 })
      .toFile(outPath);
    results[`image_d${diff}`] = `${URL_PREFIX}/uploads/${outName}`;
  }
  return results;
}

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

// Optimize all existing images in-place.
// Only touches the main full-size JPEG (2000px source) — skips thumbnails,
// per-difficulty crops (_d3-_d6), and originals (_orig.*) to avoid degrading
// the files the app shows users or the source used for re-rendering.
app.post('/api/optimize-images', async (req, res) => {
  const files = fs.readdirSync(uploadsDir).filter(f =>
    /\.(jpg|jpeg|png)$/i.test(f) &&
    !/_thumb\./i.test(f) &&
    !/_d[3-6]\.jpg$/i.test(f) &&
    !/_orig\./i.test(f)
  );
  const results = [];
  for (const file of files) {
    const filePath = path.join(uploadsDir, file);
    const sizeBefore = fs.statSync(filePath).size;
    try {
      const tmpPath = filePath + '.tmp';
      await sharp(filePath)
        .rotate()
        .resize(2000, 2000, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 95 })
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

// Clean up uploads not referenced by any location (all 7 file columns).
app.post('/api/cleanup-uploads', (req, res) => {
  const rows = db.prepare(
    'SELECT image, thumbnail, original_image, image_d3, image_d4, image_d5, image_d6 FROM locations'
  ).all();
  const usedFiles = new Set();
  rows.forEach(row => {
    [row.image, row.thumbnail, row.original_image, row.image_d3, row.image_d4, row.image_d5, row.image_d6]
      .forEach(url => { if (url) usedFiles.add(url.split('/').pop()); });
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
  try {
    await sendBrevoEmail({
      to: [{ email: 'sabinovelasquez@gmail.com', name: 'Sabino' }],
      subject: `Nuevo tester: ${name.trim()} (${cleanPlatform})`,
      htmlContent: `<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:2rem;">
        <h2 style="color:#1565C0;">Nuevo Tester</h2>
        <p><strong>Nombre:</strong> ${name.trim()}</p>
        <p><strong>Email:</strong> ${cleanEmail}</p>
        <p><strong>Plataforma:</strong> ${cleanPlatform}</p>
        <p><strong>Idioma:</strong> ${cleanLang.toUpperCase()}</p>
      </div>`,
    });
  } catch (_) { /* don't block signup if notification fails */ }

  res.json({ ok: true, id: result.lastInsertRowid });
});

app.get('/api/testers', (req, res) => {
  const rows = db.prepare('SELECT * FROM testers ORDER BY created_at DESC').all();
  res.json(rows.map(rowToTester));
});

app.put('/api/testers/:id', (req, res) => {
  const fields = [];
  const values = [];
  if (req.body.enrolled !== undefined) {
    fields.push('enrolled = ?');
    values.push(req.body.enrolled ? 1 : 0);
  }
  if (req.body.lang !== undefined) {
    const lang = String(req.body.lang).toLowerCase();
    if (lang !== 'es' && lang !== 'en') return res.status(400).json({ error: 'lang must be es or en' });
    fields.push('lang = ?');
    values.push(lang);
  }
  if (req.body.unsubscribed !== undefined) {
    fields.push('unsubscribed = ?');
    values.push(req.body.unsubscribed ? 1 : 0);
  }
  if (!fields.length) return res.json({ ok: true });
  values.push(req.params.id);
  db.prepare(`UPDATE testers SET ${fields.join(', ')} WHERE id = ?`).run(...values);
  res.json({ ok: true });
});

app.delete('/api/testers/:id', (req, res) => {
  db.prepare('DELETE FROM testers WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

// --- Opt-out helpers (HMAC-signed tokens; stateless) -------------------------
const crypto = require('crypto');
const OPT_OUT_SECRET = process.env.OPT_OUT_SECRET || process.env.BREVO_API_KEY || 'dev-secret-change-me';
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL || 'https://games.sabino.cl/zoominchile';

function optOutToken(email) {
  return crypto
    .createHmac('sha256', OPT_OUT_SECRET)
    .update(String(email).toLowerCase())
    .digest('hex')
    .slice(0, 20);
}

function buildOptOutUrl(email) {
  const token = optOutToken(email);
  const encoded = encodeURIComponent(email);
  return `${PUBLIC_BASE_URL}/api/testers/unsubscribe?email=${encoded}&token=${token}`;
}

// Public GET endpoint triggered from the email footer link. No auth — the
// HMAC token proves the recipient owns the email address. Returns a small
// confirmation HTML page (not JSON) because it's rendered in a browser.
app.get('/api/testers/unsubscribe', (req, res) => {
  const email = String(req.query.email || '').trim().toLowerCase();
  const token = String(req.query.token || '');
  const lang = req.query.lang === 'en' ? 'en' : 'es';

  if (!email || !token) {
    return res.status(400).send(renderUnsubscribePage({ lang, ok: false, reason: 'missing' }));
  }
  const expected = optOutToken(email);
  // Constant-time comparison to avoid timing attacks.
  const ok = expected.length === token.length
    && crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(token));
  if (!ok) {
    return res.status(400).send(renderUnsubscribePage({ lang, ok: false, reason: 'invalid' }));
  }

  const tester = db.prepare('SELECT id FROM testers WHERE email = ?').get(email);
  if (tester) {
    db.prepare('UPDATE testers SET unsubscribed = 1 WHERE id = ?').run(tester.id);
  }
  res.send(renderUnsubscribePage({ lang, ok: true, email }));
});

function renderUnsubscribePage({ lang, ok, email, reason }) {
  const isEn = lang === 'en';
  const title = ok
    ? (isEn ? 'Unsubscribed' : 'Suscripción cancelada')
    : (isEn ? 'Invalid link' : 'Enlace inválido');
  const body = ok
    ? (isEn
        ? `You won't receive any more emails at <strong>${email}</strong>.`
        : `No recibirás más correos en <strong>${email}</strong>.`)
    : (isEn
        ? 'This unsubscribe link is invalid or expired.'
        : 'Este enlace para cancelar la suscripción no es válido o ha expirado.');
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} · Zoom-In Chile</title>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@700&family=Plus+Jakarta+Sans:wght@400;500&display=swap" rel="stylesheet">
<style>
body{margin:0;font-family:'Plus Jakarta Sans',-apple-system,sans-serif;background:#F5F7FA;color:#1A1A1A;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;}
.card{max-width:480px;width:100%;background:#fff;border-radius:16px;box-shadow:0 12px 32px rgba(0,0,0,.08);overflow:hidden;text-align:center;}
.header{background:linear-gradient(135deg,#1565C0,#1976D2);color:#fff;padding:28px 24px;}
.header img{width:64px;height:64px;border-radius:14px;margin-bottom:10px;}
.header h1{margin:0;font-family:'Space Grotesk',sans-serif;font-size:20px;}
.body{padding:32px 28px;font-size:15px;color:#374151;line-height:1.6;}
.body strong{color:#1A1A1A;}
.footer{padding:18px;border-top:1px solid #E5E7EB;background:#FAFBFC;font-size:12px;color:#6B7280;}
.footer a{color:#1565C0;text-decoration:none;}
</style></head><body>
<div class="card">
<div class="header">
<img src="https://games.sabino.cl/zoominchile/icon.png" alt="">
<h1>${title}</h1>
</div>
<div class="body"><p>${body}</p></div>
<div class="footer"><a href="https://games.sabino.cl/zoominchile">games.sabino.cl/zoominchile</a></div>
</div>
</body></html>`;
}

// --- Bulk notification: download email --------------------------------------
async function notifyDownloadBulkHandler(req, res) {
  const testers = db.prepare(`
    SELECT * FROM testers
    WHERE enrolled = 1 AND notified = 0 AND unsubscribed = 0 AND platform = 'android'
  `).all();
  if (testers.length === 0) return res.json({ ok: true, sent: 0, message: 'No testers to notify' });

  let sent = 0;
  const errors = [];
  for (const tester of testers) {
    try {
      const { subject, html } = renderDownloadEmail({
        name: tester.name,
        lang: tester.lang,
        optOutUrl: buildOptOutUrl(tester.email),
      });
      await sendBrevoEmail({
        to: [{ email: tester.email, name: tester.name }],
        subject,
        htmlContent: html,
      });
      db.prepare('UPDATE testers SET notified = 1 WHERE id = ?').run(tester.id);
      sent++;
    } catch (e) {
      errors.push({ email: tester.email, error: e.message });
    }
  }
  res.json({ ok: true, sent, total: testers.length, errors: errors.length > 0 ? errors : undefined });
}
app.post('/api/testers/notify-download', notifyDownloadBulkHandler);

// --- Bulk notification: release / update email ------------------------------
app.post('/api/testers/notify-release', async (req, res) => {
  const releaseId = await resolveReleaseId(req.body && req.body.releaseId);
  if (!releaseId) return res.status(400).json({ error: 'No release selected and no current release set' });
  const release = db.prepare('SELECT * FROM releases WHERE id = ?').get(releaseId);
  if (!release) return res.status(404).json({ error: 'Release not found' });
  const releaseDto = rowToRelease(release);

  const testers = db.prepare(`
    SELECT t.* FROM testers t
    WHERE t.enrolled = 1
      AND t.unsubscribed = 0
      AND t.platform = 'android'
      AND NOT EXISTS (
        SELECT 1 FROM release_notifications rn
        WHERE rn.tester_id = t.id AND rn.release_id = @releaseId
      )
  `).all({ releaseId });
  if (testers.length === 0) return res.json({ ok: true, sent: 0, message: 'No testers pending for this release' });

  let sent = 0;
  const errors = [];
  const markSent = db.prepare(
    'INSERT OR IGNORE INTO release_notifications (release_id, tester_id) VALUES (?, ?)'
  );

  for (const tester of testers) {
    try {
      const { subject, html } = renderReleaseEmail({
        name: tester.name,
        lang: tester.lang,
        release: releaseDto,
        optOutUrl: buildOptOutUrl(tester.email),
      });
      await sendBrevoEmail({
        to: [{ email: tester.email, name: tester.name }],
        subject,
        htmlContent: html,
      });
      markSent.run(releaseId, tester.id);
      sent++;
    } catch (e) {
      errors.push({ email: tester.email, error: e.message });
    }
  }
  res.json({ ok: true, sent, total: testers.length, errors: errors.length > 0 ? errors : undefined });
});

// --- Individual notifications (one tester) ----------------------------------
async function notifyDownloadIndividualHandler(req, res) {
  const tester = db.prepare('SELECT * FROM testers WHERE id = ?').get(req.params.id);
  if (!tester) return res.status(404).json({ error: 'Tester not found' });
  if (tester.unsubscribed) return res.status(400).json({ error: 'Tester has unsubscribed from emails' });
  const lang = (req.body && req.body.lang) || tester.lang || 'es';
  try {
    const { subject, html } = renderDownloadEmail({
      name: tester.name,
      lang,
      optOutUrl: buildOptOutUrl(tester.email),
    });
    await sendBrevoEmail({
      to: [{ email: tester.email, name: tester.name }],
      subject,
      htmlContent: html,
    });
    db.prepare('UPDATE testers SET notified = 1 WHERE id = ?').run(tester.id);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
app.post('/api/testers/:id/notify-download', notifyDownloadIndividualHandler);

app.post('/api/testers/:id/notify-release', async (req, res) => {
  const tester = db.prepare('SELECT * FROM testers WHERE id = ?').get(req.params.id);
  if (!tester) return res.status(404).json({ error: 'Tester not found' });
  if (tester.unsubscribed) return res.status(400).json({ error: 'Tester has unsubscribed from emails' });
  const releaseId = await resolveReleaseId(req.body && req.body.releaseId);
  if (!releaseId) return res.status(400).json({ error: 'No release selected and no current release set' });
  const release = db.prepare('SELECT * FROM releases WHERE id = ?').get(releaseId);
  if (!release) return res.status(404).json({ error: 'Release not found' });
  const releaseDto = rowToRelease(release);
  const force = !!(req.body && req.body.force);
  const lang = (req.body && req.body.lang) || tester.lang || 'es';

  const already = db.prepare(
    'SELECT 1 FROM release_notifications WHERE release_id = ? AND tester_id = ?'
  ).get(releaseId, tester.id);
  if (already && !force) {
    return res.status(409).json({ error: 'Tester already notified for this release', alreadySent: true });
  }

  try {
    const { subject, html } = renderReleaseEmail({
      name: tester.name,
      lang,
      release: releaseDto,
      optOutUrl: buildOptOutUrl(tester.email),
    });
    await sendBrevoEmail({
      to: [{ email: tester.email, name: tester.name }],
      subject,
      htmlContent: html,
    });
    if (force && already) {
      db.prepare(
        'UPDATE release_notifications SET sent_at = datetime(\'now\') WHERE release_id = ? AND tester_id = ?'
      ).run(releaseId, tester.id);
    } else {
      db.prepare(
        'INSERT OR IGNORE INTO release_notifications (release_id, tester_id) VALUES (?, ?)'
      ).run(releaseId, tester.id);
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Helper: resolve a releaseId from the request body, falling back to the
// release marked as is_current, or the most recent one if none is marked.
async function resolveReleaseId(requestedId) {
  if (requestedId) return Number(requestedId);
  const row = db.prepare(`
    SELECT id FROM releases
    ORDER BY is_current DESC, released_at DESC, id DESC
    LIMIT 1
  `).get();
  return row ? row.id : null;
}

// --- Deprecated aliases: keep old callers working (e.g. old frontend JS) ----
app.post('/api/testers/notify', notifyDownloadBulkHandler);
app.post('/api/testers/:id/notify', notifyDownloadIndividualHandler);

// ============================================================
// RELEASES
// ============================================================
app.get('/api/releases', (req, res) => {
  const rows = db.prepare(
    'SELECT * FROM releases ORDER BY is_current DESC, released_at DESC, id DESC'
  ).all();
  res.json(rows.map(rowToRelease));
});

app.get('/api/releases/current', (req, res) => {
  const row = db.prepare(`
    SELECT * FROM releases
    ORDER BY is_current DESC, released_at DESC, id DESC
    LIMIT 1
  `).get();
  if (!row) return res.status(404).json({ error: 'No releases yet' });
  res.json(rowToRelease(row));
});

// Suggest a version by reading pubspec.yaml in the parent Flutter project,
// and if a matching entry exists in CHANGELOG.md, also suggest the release
// date + bilingual notes. The latter three fields are optional — older
// clients only expecting `suggestedVersion` keep working.
app.get('/api/releases/suggest-version', (req, res) => {
  try {
    const content = fs.readFileSync(path.join(__dirname, '..', 'pubspec.yaml'), 'utf8');
    const match = content.match(/^version:\s*([^\s#]+)/m);
    const suggestedVersion = match ? match[1] : null;

    const entry = suggestedVersion ? readChangelogEntry(suggestedVersion) : null;
    res.json({
      suggestedVersion,
      releasedAt: entry?.releasedAt || null,
      notesEs: entry?.notesEs || null,
      notesEn: entry?.notesEn || null,
    });
  } catch (_) {
    res.json({ suggestedVersion: null, releasedAt: null, notesEs: null, notesEn: null });
  }
});

// Stats for the admin UI: how many testers are eligible and how many already
// received the email for a given release. Used in the "Send to testers" panel.
app.get('/api/releases/:id/stats', (req, res) => {
  const release = db.prepare('SELECT id FROM releases WHERE id = ?').get(req.params.id);
  if (!release) return res.status(404).json({ error: 'Release not found' });
  const enrolled = db.prepare(`
    SELECT COUNT(*) AS c FROM testers
    WHERE enrolled = 1 AND unsubscribed = 0 AND platform = 'android'
  `).get().c;
  const notified = db.prepare(`
    SELECT COUNT(*) AS c FROM release_notifications rn
    JOIN testers t ON t.id = rn.tester_id
    WHERE rn.release_id = ? AND t.enrolled = 1 AND t.unsubscribed = 0 AND t.platform = 'android'
  `).get(req.params.id).c;
  res.json({ enrolled, notified, pending: Math.max(0, enrolled - notified) });
});

// Preview the email HTML (ES or EN) for a given release, using placeholder
// tester data. Returns raw HTML so the admin UI can stuff it into an iframe.
app.get('/api/releases/:id/preview', (req, res) => {
  const release = db.prepare('SELECT * FROM releases WHERE id = ?').get(req.params.id);
  if (!release) return res.status(404).send('Release not found');
  const lang = req.query.lang === 'en' ? 'en' : 'es';
  const kind = req.query.kind === 'download' ? 'download' : 'release';
  const placeholderName = lang === 'en' ? '[Name]' : '[Nombre]';
  const placeholderOptOut = `${PUBLIC_BASE_URL}/api/testers/unsubscribe?email=preview@example.com&token=preview`;
  const rendered = kind === 'download'
    ? renderDownloadEmail({ name: placeholderName, lang, optOutUrl: placeholderOptOut })
    : renderReleaseEmail({ name: placeholderName, lang, release: rowToRelease(release), optOutUrl: placeholderOptOut });
  res.set('content-type', 'text/html; charset=utf-8');
  res.send(rendered.html);
});

// Preview a standalone download email without requiring a release row.
app.get('/api/releases/preview-download', (req, res) => {
  const lang = req.query.lang === 'en' ? 'en' : 'es';
  const placeholderName = lang === 'en' ? '[Name]' : '[Nombre]';
  const placeholderOptOut = `${PUBLIC_BASE_URL}/api/testers/unsubscribe?email=preview@example.com&token=preview`;
  const rendered = renderDownloadEmail({ name: placeholderName, lang, optOutUrl: placeholderOptOut });
  res.set('content-type', 'text/html; charset=utf-8');
  res.send(rendered.html);
});

app.post('/api/releases', (req, res) => {
  const { version, releasedAt, notesEs, notesEn, isCurrent } = req.body || {};
  if (!version || !String(version).trim()) {
    return res.status(400).json({ error: 'Version is required' });
  }
  const cleanVersion = String(version).trim();
  const cleanDate = (releasedAt && String(releasedAt).trim()) || new Date().toISOString().slice(0, 10);

  try {
    const insert = db.transaction(() => {
      if (isCurrent) {
        db.prepare('UPDATE releases SET is_current = 0').run();
      }
      return db.prepare(`
        INSERT INTO releases (version, released_at, notes_es, notes_en, is_current)
        VALUES (?, ?, ?, ?, ?)
      `).run(cleanVersion, cleanDate, notesEs || '', notesEn || '', isCurrent ? 1 : 0);
    });
    const result = insert();
    res.json({ ok: true, id: result.lastInsertRowid });
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) {
      return res.status(409).json({ error: `Version ${cleanVersion} already exists` });
    }
    res.status(500).json({ error: e.message });
  }
});

app.put('/api/releases/:id', (req, res) => {
  const existing = db.prepare('SELECT id FROM releases WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Release not found' });
  const { version, releasedAt, notesEs, notesEn, isCurrent } = req.body || {};
  if (!version || !String(version).trim()) {
    return res.status(400).json({ error: 'Version is required' });
  }

  try {
    const update = db.transaction(() => {
      if (isCurrent) {
        db.prepare('UPDATE releases SET is_current = 0').run();
      }
      db.prepare(`
        UPDATE releases
        SET version = ?, released_at = ?, notes_es = ?, notes_en = ?, is_current = ?, updated_at = datetime('now')
        WHERE id = ?
      `).run(
        String(version).trim(),
        releasedAt || new Date().toISOString().slice(0, 10),
        notesEs || '',
        notesEn || '',
        isCurrent ? 1 : 0,
        req.params.id
      );
    });
    update();
    res.json({ ok: true });
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) {
      return res.status(409).json({ error: 'Version already exists' });
    }
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/releases/:id', (req, res) => {
  db.prepare('DELETE FROM releases WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

// ============================================================
// PROGRESS BACKUP — short-code, server-backed "Nintendo password"
// ============================================================
const BACKUP_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // 31 chars, no 0/O, 1/I/L, S/5
const BACKUP_CODE_LEN = 8;
const BACKUP_TTL_DAYS = 30;
const BACKUP_MAX_SIZE = 200 * 1024; // 200 KB safety cap

// In-memory rate limiters (IP → timestamps[]). Sliding window.
const backupCreateHits = new Map();
const backupRestoreHits = new Map();

function rateLimit(map, ip, windowMs, maxHits) {
  const now = Date.now();
  const arr = (map.get(ip) || []).filter(t => now - t < windowMs);
  if (arr.length >= maxHits) {
    map.set(ip, arr);
    return false;
  }
  arr.push(now);
  map.set(ip, arr);
  return true;
}

function generateBackupCode() {
  const crypto = require('crypto');
  let code = '';
  const bytes = crypto.randomBytes(BACKUP_CODE_LEN);
  for (let i = 0; i < BACKUP_CODE_LEN; i++) {
    code += BACKUP_CODE_ALPHABET[bytes[i] % BACKUP_CODE_ALPHABET.length];
  }
  return code;
}

function normalizeCode(raw) {
  return String(raw || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function cleanupExpiredBackups() {
  try {
    db.prepare(`DELETE FROM progress_backups WHERE expires_at < datetime('now')`).run();
  } catch (_) { /* ignore */ }
}

app.post('/api/progress/backup', (req, res) => {
  const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
  if (!rateLimit(backupCreateHits, ip, 60 * 60 * 1000, 20)) {
    return res.status(429).json({ error: 'Too many backup requests, try again later' });
  }

  const progress = req.body && req.body.progress;
  if (!progress || typeof progress !== 'object') {
    return res.status(400).json({ error: 'Missing progress payload' });
  }

  let json;
  try {
    json = JSON.stringify(progress);
  } catch (e) {
    return res.status(400).json({ error: 'Invalid progress payload' });
  }
  if (Buffer.byteLength(json, 'utf8') > BACKUP_MAX_SIZE) {
    return res.status(413).json({ error: 'Progress payload too large' });
  }

  cleanupExpiredBackups();

  // Generate a unique code (retry on collision — extremely unlikely)
  let code;
  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = generateBackupCode();
    const existing = db.prepare('SELECT 1 FROM progress_backups WHERE code = ?').get(candidate);
    if (!existing) { code = candidate; break; }
  }
  if (!code) return res.status(500).json({ error: 'Could not generate code' });

  const expiresAt = new Date(Date.now() + BACKUP_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();

  db.prepare(`
    INSERT INTO progress_backups (code, progress_json, expires_at, ip)
    VALUES (@code, @json, @expiresAt, @ip)
  `).run({ code, json, expiresAt, ip: String(ip).slice(0, 64) });

  res.json({ code, expiresAt });
});

app.get('/api/progress/restore/:code', (req, res) => {
  const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
  if (!rateLimit(backupRestoreHits, ip, 10 * 60 * 1000, 10)) {
    return res.status(429).json({ error: 'Too many restore attempts, try again later' });
  }

  const code = normalizeCode(req.params.code);
  if (!code || code.length !== BACKUP_CODE_LEN) {
    return res.status(400).json({ error: 'Invalid code format' });
  }

  const row = db.prepare(`
    SELECT progress_json, expires_at FROM progress_backups
    WHERE code = ? AND expires_at >= datetime('now')
  `).get(code);

  if (!row) return res.status(404).json({ error: 'Code not found or expired' });

  let progress;
  try {
    progress = JSON.parse(row.progress_json);
  } catch (e) {
    return res.status(500).json({ error: 'Stored progress is corrupt' });
  }

  res.json({ progress, expiresAt: row.expires_at });
});

app.post('/api/progress/backup/email', async (req, res) => {
  const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
  if (!rateLimit(backupCreateHits, ip, 60 * 60 * 1000, 20)) {
    return res.status(429).json({ error: 'Too many requests, try again later' });
  }

  const { code: rawCode, email, lang } = req.body || {};
  const code = normalizeCode(rawCode);
  if (!code || code.length !== BACKUP_CODE_LEN) {
    return res.status(400).json({ error: 'Invalid code format' });
  }
  if (!email || typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Invalid email' });
  }

  const row = db.prepare(`
    SELECT expires_at FROM progress_backups
    WHERE code = ? AND expires_at >= datetime('now')
  `).get(code);
  if (!row) return res.status(404).json({ error: 'Code not found or expired' });

  try {
    const { subject, html } = renderProgressBackupEmail({
      code,
      expiresAt: row.expires_at,
      lang: lang === 'en' ? 'en' : 'es',
    });
    await sendBrevoEmail({
      to: [{ email, name: email.split('@')[0] }],
      subject,
      htmlContent: html,
    });
    res.json({ ok: true });
  } catch (e) {
    console.error('backup email failed:', e);
    res.status(500).json({ error: 'Failed to send email' });
  }
});

// ============================================================
// START
// ============================================================
app.listen(PORT, BIND, () => {
  console.log(`✨ Admin server running at http://${BIND}:${PORT}${URL_PREFIX}`);
  writeStats().catch(() => {});
});
