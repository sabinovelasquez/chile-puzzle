// Parser for the repo-root CHANGELOG.md.
//
// Format expected (newest first):
//
//   ## <version> — <YYYY-MM-DD>
//
//   **ES**
//   - item one
//   - item two
//
//   **EN**
//   - item one
//   - item two
//
// The admin reads this at /api/releases/suggest-version time to
// auto-populate release notes in the "Edit Release" modal. Any parse
// failure returns null for that entry — the admin falls back to an
// empty textarea, same behavior as before the feature existed.

const fs = require('fs');
const path = require('path');

// Pure function: takes the markdown string, returns a map keyed by
// version string (e.g. "1.8.0+11") to { releasedAt, notesEs, notesEn }.
function parseChangelog(markdown) {
  const out = {};
  if (typeof markdown !== 'string' || !markdown.trim()) return out;

  // Split on "## " section headers. The first chunk is the file preamble
  // (title + intro), which we discard.
  const chunks = markdown.split(/\n## /);
  for (let i = 1; i < chunks.length; i++) {
    const chunk = chunks[i];
    const newlineIdx = chunk.indexOf('\n');
    if (newlineIdx === -1) continue;

    const header = chunk.slice(0, newlineIdx).trim();
    const body = chunk.slice(newlineIdx + 1);

    // Header: "<version> — <date>" (em-dash). Date is optional.
    const [versionRaw, dateRaw] = header.split(/\s+—\s+|\s+-\s+/);
    const version = (versionRaw || '').trim();
    if (!version) continue;

    const releasedAt = (dateRaw || '').trim() || null;

    const notesEs = extractList(body, 'ES');
    const notesEn = extractList(body, 'EN');
    if (notesEs === null && notesEn === null) continue;

    out[version] = {
      releasedAt,
      notesEs: notesEs || '',
      notesEn: notesEn || '',
    };
  }
  return out;
}

// Finds the "**LABEL**" sub-section within a section body and returns
// its bullet items joined with "\n" (matching the existing notes_es /
// notes_en "one item per line" convention used by email-templates.js).
// Returns null if the sub-section is missing.
function extractList(body, label) {
  const re = new RegExp(`\\*\\*${label}\\*\\*\\s*\\n([\\s\\S]*?)(?:\\n\\*\\*|$)`);
  const m = body.match(re);
  if (!m) return null;

  const items = [];
  for (const rawLine of m[1].split('\n')) {
    const line = rawLine.trim();
    if (line.startsWith('- ')) items.push(line.slice(2).trim());
  }
  return items.length ? items.join('\n') : null;
}

// IO wrapper: reads CHANGELOG.md at repo root (one level up from
// admin-backend) and returns the entry for `version`, or null if
// missing / unreadable / unparseable.
function readChangelogEntry(version) {
  try {
    const md = fs.readFileSync(path.join(__dirname, '..', 'CHANGELOG.md'), 'utf8');
    return parseChangelog(md)[version] || null;
  } catch (_) {
    return null;
  }
}

module.exports = { parseChangelog, readChangelogEntry };
