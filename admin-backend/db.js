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
`);

// Migrate: add platform to testers if missing
try {
  db.prepare('SELECT platform FROM testers LIMIT 0').get();
} catch (_) {
  db.exec("ALTER TABLE testers ADD COLUMN platform TEXT NOT NULL DEFAULT 'android'");
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
    tip: { en: row.tip_en, es: row.tip_es },
    tipsByDifficulty: {
      '4': { en: row.tip_normal_en || '', es: row.tip_normal_es || '' },
      '5': { en: row.tip_hard_en   || '', es: row.tip_hard_es   || '' },
      '6': { en: row.tip_expert_en || '', es: row.tip_expert_es || '' },
    },
    crop: { x: row.crop_x, y: row.crop_y, w: row.crop_w, h: row.crop_h },
    difficulty: JSON.parse(row.difficulty),
    createdAt: row.created_at,
  };
}

function locationToParams(obj) {
  const t = obj.tipsByDifficulty || {};
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
    tip_en: obj.tip?.en || '',
    tip_es: obj.tip?.es || '',
    tip_normal_en: t['4']?.en || '',
    tip_normal_es: t['4']?.es || '',
    tip_hard_en:   t['5']?.en || '',
    tip_hard_es:   t['5']?.es || '',
    tip_expert_en: t['6']?.en || '',
    tip_expert_es: t['6']?.es || '',
    crop_x: obj.crop?.x ?? 0.15,
    crop_y: obj.crop?.y ?? 0.15,
    crop_w: obj.crop?.w ?? 0.7,
    crop_h: obj.crop?.h ?? 0.7,
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
    createdAt: row.created_at,
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
};
