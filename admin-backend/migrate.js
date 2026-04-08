#!/usr/bin/env node
/**
 * One-time migration: JSON files → SQLite database.
 * Run: node migrate.js
 * Safe to run multiple times (skips existing records).
 */

const fs = require('fs');
const path = require('path');
const { db, locationToParams } = require('./db');

const dataDir = path.join(__dirname, 'data');

function readJSON(file) {
  try {
    return JSON.parse(fs.readFileSync(path.join(dataDir, file), 'utf8'));
  } catch {
    return file.includes('scoring') ? {} : [];
  }
}

const locations = readJSON('locations.json');
const zones = readJSON('zones.json');
const trophies = readJSON('trophies.json');
const scoring = readJSON('scoring.json');

console.log(`\nMigrating to SQLite...`);
console.log(`  Locations: ${locations.length}`);
console.log(`  Zones: ${zones.length}`);
console.log(`  Trophies: ${trophies.length}`);

// --- Zones ---
const insertZone = db.prepare(`
  INSERT OR IGNORE INTO zones (id, name_en, name_es, "order", icon)
  VALUES (@id, @name_en, @name_es, @order, @icon)
`);

const zonesTx = db.transaction(() => {
  for (const z of zones) {
    insertZone.run({
      id: z.id,
      name_en: z.name?.en || '',
      name_es: z.name?.es || '',
      order: z.order ?? 99,
      icon: z.icon || 'landscape',
    });
  }
});
zonesTx();
console.log(`  ✓ Zones migrated`);

// --- Locations ---
const insertLoc = db.prepare(`
  INSERT OR IGNORE INTO locations
    (id, name_en, name_es, region, required_points, latitude, longitude,
     image, thumbnail, tip_en, tip_es, crop_x, crop_y, crop_w, crop_h,
     difficulty, created_at, updated_at)
  VALUES
    (@id, @name_en, @name_es, @region, @required_points, @latitude, @longitude,
     @image, @thumbnail, @tip_en, @tip_es, @crop_x, @crop_y, @crop_w, @crop_h,
     @difficulty, @created_at, @updated_at)
`);

const locsTx = db.transaction(() => {
  for (const loc of locations) {
    const params = locationToParams(loc);
    params.created_at = '2024-01-01T00:00:00';
    params.updated_at = '2024-01-01T00:00:00';
    insertLoc.run(params);
  }
});
locsTx();
console.log(`  ✓ Locations migrated`);

// --- Trophies ---
const insertTrophy = db.prepare(`
  INSERT OR IGNORE INTO trophies
    (id, name_en, name_es, description_en, description_es, icon, type, condition_json)
  VALUES (@id, @name_en, @name_es, @description_en, @description_es, @icon, @type, @condition_json)
`);

const trophiesTx = db.transaction(() => {
  for (const t of trophies) {
    insertTrophy.run({
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
trophiesTx();
console.log(`  ✓ Trophies migrated`);

// --- Scoring ---
if (scoring.basePoints) {
  db.prepare(`
    UPDATE scoring SET
      base_points_3 = @bp3, base_points_4 = @bp4,
      base_points_5 = @bp5, base_points_6 = @bp6,
      time_bonus_threshold_secs = @tbt, time_bonus_points = @tbp,
      move_efficiency_bonus_pct = @meb
    WHERE id = 1
  `).run({
    bp3: scoring.basePoints['3'] || 50,
    bp4: scoring.basePoints['4'] || 100,
    bp5: scoring.basePoints['5'] || 200,
    bp6: scoring.basePoints['6'] || 350,
    tbt: scoring.timeBonusThresholdSecs || 60,
    tbp: scoring.timeBonusPoints || 50,
    meb: scoring.moveEfficiencyBonusPercent || 20,
  });
  console.log(`  ✓ Scoring migrated`);
}

// --- Verify ---
const counts = {
  locations: db.prepare('SELECT COUNT(*) as n FROM locations').get().n,
  zones: db.prepare('SELECT COUNT(*) as n FROM zones').get().n,
  trophies: db.prepare('SELECT COUNT(*) as n FROM trophies').get().n,
};
console.log(`\n✅ Migration complete!`);
console.log(`  DB: ${path.join(dataDir, 'database.sqlite')}`);
console.log(`  Locations: ${counts.locations}, Zones: ${counts.zones}, Trophies: ${counts.trophies}`);
console.log(`\nOriginal JSON files preserved as backup.\n`);
