const Database = require('better-sqlite3');
const path = require('path');

const dbPath = path.join(__dirname, 'data', 'database.sqlite');
const db = new Database(dbPath);

// Performance: WAL mode for better concurrent reads
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// --- Schema creation (idempotent) ---
db.exec(`
  CREATE TABLE IF NOT EXISTS locations (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_es TEXT NOT NULL,
    region TEXT NOT NULL,
    required_points INTEGER NOT NULL DEFAULT 0,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    image TEXT NOT NULL,
    thumbnail TEXT NOT NULL,
    tip_en TEXT NOT NULL DEFAULT '',
    tip_es TEXT NOT NULL DEFAULT '',
    crop_x REAL NOT NULL DEFAULT 0.15,
    crop_y REAL NOT NULL DEFAULT 0.15,
    crop_w REAL NOT NULL DEFAULT 0.7,
    crop_h REAL NOT NULL DEFAULT 0.7,
    difficulty TEXT NOT NULL DEFAULT '[3,4,5,6]',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_loc_region ON locations(region);
  CREATE INDEX IF NOT EXISTS idx_loc_points ON locations(required_points);
  CREATE INDEX IF NOT EXISTS idx_loc_created ON locations(created_at);

  CREATE TABLE IF NOT EXISTS zones (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_es TEXT NOT NULL,
    "order" INTEGER NOT NULL DEFAULT 99,
    icon TEXT NOT NULL DEFAULT 'landscape'
  );

  CREATE TABLE IF NOT EXISTS trophies (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_es TEXT NOT NULL,
    description_en TEXT NOT NULL DEFAULT '',
    description_es TEXT NOT NULL DEFAULT '',
    icon TEXT NOT NULL DEFAULT 'emoji_events',
    type TEXT NOT NULL DEFAULT 'milestone',
    condition_json TEXT NOT NULL DEFAULT '{}'
  );

  CREATE TABLE IF NOT EXISTS scoring (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    base_points_3 INTEGER NOT NULL DEFAULT 50,
    base_points_4 INTEGER NOT NULL DEFAULT 100,
    base_points_5 INTEGER NOT NULL DEFAULT 200,
    base_points_6 INTEGER NOT NULL DEFAULT 350,
    time_bonus_threshold_secs INTEGER NOT NULL DEFAULT 60,
    time_bonus_points INTEGER NOT NULL DEFAULT 50,
    move_efficiency_bonus_pct INTEGER NOT NULL DEFAULT 20
  );

  CREATE TABLE IF NOT EXISTS leaderboard (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    initials TEXT NOT NULL CHECK(length(initials) = 3),
    total_points INTEGER NOT NULL DEFAULT 0,
    puzzles_completed INTEGER NOT NULL DEFAULT 0,
    time_seconds INTEGER NOT NULL DEFAULT 0,
    moves INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_lb_points ON leaderboard(total_points DESC);

  CREATE TABLE IF NOT EXISTS location_leaderboard (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    location_id TEXT NOT NULL,
    difficulty INTEGER NOT NULL,
    initials TEXT NOT NULL CHECK(length(initials) = 3),
    points INTEGER NOT NULL DEFAULT 0,
    time_seconds INTEGER NOT NULL DEFAULT 0,
    moves INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(location_id, difficulty, initials)
  );
  CREATE INDEX IF NOT EXISTS idx_loc_lb ON location_leaderboard(location_id, difficulty, points DESC, time_seconds ASC);

  CREATE TABLE IF NOT EXISTS testers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    lang TEXT NOT NULL DEFAULT 'es',
    enrolled INTEGER NOT NULL DEFAULT 0,
    notified INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_testers_email ON testers(email);

  CREATE TABLE IF NOT EXISTS releases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT UNIQUE NOT NULL,
    released_at TEXT NOT NULL DEFAULT (date('now')),
    notes_es TEXT NOT NULL DEFAULT '',
    notes_en TEXT NOT NULL DEFAULT '',
    is_current INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_releases_current ON releases(is_current);

  CREATE TABLE IF NOT EXISTS release_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    release_id INTEGER NOT NULL,
    tester_id INTEGER NOT NULL,
    sent_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(release_id, tester_id),
    FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE,
    FOREIGN KEY (tester_id) REFERENCES testers(id) ON DELETE CASCADE
  );
  CREATE INDEX IF NOT EXISTS idx_rel_notif_release ON release_notifications(release_id);
`);

// Migrate: add platform to testers if missing
try {
  db.prepare('SELECT platform FROM testers LIMIT 0').get();
} catch (_) {
  db.exec("ALTER TABLE testers ADD COLUMN platform TEXT NOT NULL DEFAULT 'android'");
}

// Migrate: add unsubscribed flag to testers (opt-out from emails)
try {
  db.prepare('SELECT unsubscribed FROM testers LIMIT 0').get();
} catch (_) {
  db.exec('ALTER TABLE testers ADD COLUMN unsubscribed INTEGER NOT NULL DEFAULT 0');
}

// Migrate: add time_seconds and moves to leaderboard if missing
try {
  db.prepare('SELECT time_seconds FROM leaderboard LIMIT 0').get();
} catch (_) {
  db.exec('ALTER TABLE leaderboard ADD COLUMN time_seconds INTEGER NOT NULL DEFAULT 0');
  db.exec('ALTER TABLE leaderboard ADD COLUMN moves INTEGER NOT NULL DEFAULT 0');
}

// Migrate: add tester_spots to scoring if missing
try {
  db.prepare('SELECT tester_spots FROM scoring LIMIT 0').get();
} catch (_) {
  db.exec('ALTER TABLE scoring ADD COLUMN tester_spots INTEGER NOT NULL DEFAULT 100');
}

// Migrate: add per-difficulty tip overrides (fallback to tip_en/tip_es when empty)
try {
  db.prepare('SELECT tip_normal_en FROM locations LIMIT 0').get();
} catch (_) {
  db.exec("ALTER TABLE locations ADD COLUMN tip_normal_en TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN tip_normal_es TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN tip_hard_en   TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN tip_hard_es   TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN tip_expert_en TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN tip_expert_es TEXT NOT NULL DEFAULT ''");
}

// Migrate: add active flag, original image metadata, and 16 per-difficulty crop columns.
// Backfill per-diff crops from legacy crop_* using the same interpolation formula
// as LocationModel.getCropForDifficulty() in Flutter (t = 0, 1/3, 2/3, 1).
try {
  db.prepare('SELECT active FROM locations LIMIT 0').get();
} catch (_) {
  db.exec("ALTER TABLE locations ADD COLUMN active INTEGER NOT NULL DEFAULT 1");
  db.exec("ALTER TABLE locations ADD COLUMN original_image TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN original_width INTEGER NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN original_height INTEGER NOT NULL DEFAULT 0");

  // Easy = full image (t=0)
  db.exec("ALTER TABLE locations ADD COLUMN crop_easy_x REAL NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN crop_easy_y REAL NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN crop_easy_w REAL NOT NULL DEFAULT 1");
  db.exec("ALTER TABLE locations ADD COLUMN crop_easy_h REAL NOT NULL DEFAULT 1");
  // Normal (t=1/3) — backfill computed below
  db.exec("ALTER TABLE locations ADD COLUMN crop_normal_x REAL NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN crop_normal_y REAL NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN crop_normal_w REAL NOT NULL DEFAULT 1");
  db.exec("ALTER TABLE locations ADD COLUMN crop_normal_h REAL NOT NULL DEFAULT 1");
  // Hard (t=2/3)
  db.exec("ALTER TABLE locations ADD COLUMN crop_hard_x REAL NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN crop_hard_y REAL NOT NULL DEFAULT 0");
  db.exec("ALTER TABLE locations ADD COLUMN crop_hard_w REAL NOT NULL DEFAULT 1");
  db.exec("ALTER TABLE locations ADD COLUMN crop_hard_h REAL NOT NULL DEFAULT 1");
  // Expert (t=1) = current single crop
  db.exec("ALTER TABLE locations ADD COLUMN crop_expert_x REAL NOT NULL DEFAULT 0.15");
  db.exec("ALTER TABLE locations ADD COLUMN crop_expert_y REAL NOT NULL DEFAULT 0.15");
  db.exec("ALTER TABLE locations ADD COLUMN crop_expert_w REAL NOT NULL DEFAULT 0.7");
  db.exec("ALTER TABLE locations ADD COLUMN crop_expert_h REAL NOT NULL DEFAULT 0.7");

  // Backfill from existing crop_x/y/w/h (lerp between full image and stored crop)
  const rows = db.prepare('SELECT id, crop_x, crop_y, crop_w, crop_h FROM locations').all();
  const update = db.prepare(`
    UPDATE locations SET
      crop_easy_x=0, crop_easy_y=0, crop_easy_w=1, crop_easy_h=1,
      crop_normal_x=@nx, crop_normal_y=@ny, crop_normal_w=@nw, crop_normal_h=@nh,
      crop_hard_x=@hx,   crop_hard_y=@hy,   crop_hard_w=@hw,   crop_hard_h=@hh,
      crop_expert_x=@ex, crop_expert_y=@ey, crop_expert_w=@ew, crop_expert_h=@eh
    WHERE id=@id
  `);
  const lerp = (a, b, t) => a + (b - a) * t;
  const tx = db.transaction((rows) => {
    for (const r of rows) {
      const ex = r.crop_x, ey = r.crop_y, ew = r.crop_w, eh = r.crop_h;
      update.run({
        id: r.id,
        nx: lerp(0, ex, 1 / 3), ny: lerp(0, ey, 1 / 3), nw: lerp(1, ew, 1 / 3), nh: lerp(1, eh, 1 / 3),
        hx: lerp(0, ex, 2 / 3), hy: lerp(0, ey, 2 / 3), hw: lerp(1, ew, 2 / 3), hh: lerp(1, eh, 2 / 3),
        ex, ey, ew, eh,
      });
    }
  });
  tx(rows);
}

// Migrate: add per-difficulty pre-rendered image paths.
// These are generated server-side by sharp.extract() from the raw original,
// so each difficulty gets its own high-resolution cropped JPEG instead of
// relying on Flutter's runtime OverflowBox clipping of the single image.
try {
  db.prepare('SELECT image_d3 FROM locations LIMIT 0').get();
} catch (_) {
  db.exec("ALTER TABLE locations ADD COLUMN image_d3 TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN image_d4 TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN image_d5 TEXT NOT NULL DEFAULT ''");
  db.exec("ALTER TABLE locations ADD COLUMN image_d6 TEXT NOT NULL DEFAULT ''");
}

// Ensure scoring has a default row
const scoringRow = db.prepare('SELECT id FROM scoring WHERE id = 1').get();
if (!scoringRow) {
  db.prepare('INSERT INTO scoring (id) VALUES (1)').run();
}

// --- Helpers: row <-> JSON conversion ---

function rowToLocation(row) {
  return {
    id: row.id,
    name: { en: row.name_en, es: row.name_es },
    region: row.region,
    requiredPoints: row.required_points,
    latitude: row.latitude,
    longitude: row.longitude,
    image: row.image,
    thumbnail: row.thumbnail,
    originalImage: row.original_image || '',
    originalWidth: row.original_width || 0,
    originalHeight: row.original_height || 0,
    active: row.active !== 0,
    tip: { en: row.tip_en, es: row.tip_es },
    tipsByDifficulty: {
      '4': { en: row.tip_normal_en || '', es: row.tip_normal_es || '' },
      '5': { en: row.tip_hard_en   || '', es: row.tip_hard_es   || '' },
      '6': { en: row.tip_expert_en || '', es: row.tip_expert_es || '' },
    },
    crop: { x: row.crop_x, y: row.crop_y, w: row.crop_w, h: row.crop_h },
    cropsByDifficulty: {
      '3': { x: row.crop_easy_x,   y: row.crop_easy_y,   w: row.crop_easy_w,   h: row.crop_easy_h   },
      '4': { x: row.crop_normal_x, y: row.crop_normal_y, w: row.crop_normal_w, h: row.crop_normal_h },
      '5': { x: row.crop_hard_x,   y: row.crop_hard_y,   w: row.crop_hard_w,   h: row.crop_hard_h   },
      '6': { x: row.crop_expert_x, y: row.crop_expert_y, w: row.crop_expert_w, h: row.crop_expert_h },
    },
    imagesByDifficulty: {
      '3': row.image_d3 || '',
      '4': row.image_d4 || '',
      '5': row.image_d5 || '',
      '6': row.image_d6 || '',
    },
    difficulty: JSON.parse(row.difficulty),
    createdAt: row.created_at,
  };
}

function locationToParams(obj) {
  const t = obj.tipsByDifficulty || {};
  const c = obj.cropsByDifficulty || {};
  const i = obj.imagesByDifficulty || {};
  const defCrop = { x: 0.15, y: 0.15, w: 0.7, h: 0.7 };
  const easy   = c['3'] || { x: 0, y: 0, w: 1, h: 1 };
  const normal = c['4'] || defCrop;
  const hard   = c['5'] || defCrop;
  const expert = c['6'] || obj.crop || defCrop;
  // Legacy crop_* mirrors Expert so Flutter's interpolation keeps working
  // until the app is updated to read cropsByDifficulty directly.
  return {
    id: obj.id,
    name_en: obj.name?.en || '',
    name_es: obj.name?.es || '',
    region: obj.region || '',
    required_points: obj.requiredPoints || 0,
    latitude: obj.latitude || 0,
    longitude: obj.longitude || 0,
    image: obj.image || '',
    thumbnail: obj.thumbnail || obj.image || '',
    original_image: obj.originalImage || '',
    original_width: obj.originalWidth || 0,
    original_height: obj.originalHeight || 0,
    active: obj.active === false ? 0 : 1,
    tip_en: obj.tip?.en || '',
    tip_es: obj.tip?.es || '',
    tip_normal_en: t['4']?.en || '',
    tip_normal_es: t['4']?.es || '',
    tip_hard_en:   t['5']?.en || '',
    tip_hard_es:   t['5']?.es || '',
    tip_expert_en: t['6']?.en || '',
    tip_expert_es: t['6']?.es || '',
    crop_x: expert.x, crop_y: expert.y, crop_w: expert.w, crop_h: expert.h,
    crop_easy_x: easy.x, crop_easy_y: easy.y, crop_easy_w: easy.w, crop_easy_h: easy.h,
    crop_normal_x: normal.x, crop_normal_y: normal.y, crop_normal_w: normal.w, crop_normal_h: normal.h,
    crop_hard_x: hard.x, crop_hard_y: hard.y, crop_hard_w: hard.w, crop_hard_h: hard.h,
    crop_expert_x: expert.x, crop_expert_y: expert.y, crop_expert_w: expert.w, crop_expert_h: expert.h,
    image_d3: i['3'] || '',
    image_d4: i['4'] || '',
    image_d5: i['5'] || '',
    image_d6: i['6'] || '',
    difficulty: JSON.stringify(obj.difficulty || [3, 4, 5, 6]),
  };
}

function rowToZone(row) {
  return {
    id: row.id,
    name: { en: row.name_en, es: row.name_es },
    order: row.order,
    icon: row.icon,
  };
}

function rowToTrophy(row) {
  return {
    id: row.id,
    name: { en: row.name_en, es: row.name_es },
    description: { en: row.description_en, es: row.description_es },
    icon: row.icon,
    type: row.type,
    condition: JSON.parse(row.condition_json),
  };
}

function rowToScoring(row) {
  return {
    basePoints: {
      '3': row.base_points_3,
      '4': row.base_points_4,
      '5': row.base_points_5,
      '6': row.base_points_6,
    },
    timeBonusThresholdSecs: row.time_bonus_threshold_secs,
    timeBonusPoints: row.time_bonus_points,
    moveEfficiencyBonusPercent: row.move_efficiency_bonus_pct,
    testerSpots: row.tester_spots ?? 100,
  };
}

function rowToTester(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    lang: row.lang,
    platform: row.platform || 'android',
    enrolled: !!row.enrolled,
    notified: !!row.notified,
    unsubscribed: !!row.unsubscribed,
    createdAt: row.created_at,
  };
}

function rowToRelease(row) {
  return {
    id: row.id,
    version: row.version,
    releasedAt: row.released_at,
    notesEs: row.notes_es,
    notesEn: row.notes_en,
    isCurrent: !!row.is_current,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = {
  db,
  rowToLocation,
  locationToParams,
  rowToZone,
  rowToTrophy,
  rowToScoring,
  rowToTester,
  rowToRelease,
};
