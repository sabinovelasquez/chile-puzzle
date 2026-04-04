// --- State ---
let locations = [], zones = [], trophies = [], scoring = {};
let currentEditId = null, currentZoneId = null, currentTrophyId = null;

// --- Tab navigation ---
document.querySelectorAll('.tab').forEach(tab => {
  tab.onclick = () => {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    tab.classList.add('active');
    document.querySelector(`.tab-content[data-tab="${tab.dataset.tab}"]`).classList.add('active');
  };
});

// --- Generic helpers ---
async function fetchJSON(url) {
  const res = await fetch(url);
  return res.json();
}
async function postJSON(url, data) {
  await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
}

// ============================================================
// LOCATIONS
// ============================================================
const locForm = document.getElementById('editorForm');
const locEmpty = document.getElementById('emptyState');
const fId = document.getElementById('locId');
const fNameEn = document.getElementById('locNameEn'), fNameEs = document.getElementById('locNameEs');
const fZone = document.getElementById('locZone');
const fLat = document.getElementById('locLat'), fLng = document.getElementById('locLng');
const fImage = document.getElementById('locImage'), fThumb = document.getElementById('locThumbnail');
const fTipEn = document.getElementById('locTipEn'), fTipEs = document.getElementById('locTipEs');
const fImageUpload = document.getElementById('locImageUpload');
const imgPreviewC = document.getElementById('imagePreviewContainer');
const imgPreview = document.getElementById('imagePreview');

fImage.addEventListener('input', () => {
  if (fImage.value) { imgPreview.src = fImage.value; imgPreviewC.style.display = 'block'; }
  else { imgPreviewC.style.display = 'none'; }
});

fImageUpload.addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  const fd = new FormData(); fd.append('image', file);
  try {
    const r = await fetch('/api/upload', { method: 'POST', body: fd });
    const d = await r.json();
    if (d.url) {
      fImage.value = d.url;
      if (!fThumb.value || fThumb.value.startsWith('/uploads')) fThumb.value = d.url;
      imgPreview.src = d.url; imgPreviewC.style.display = 'block';
    }
  } catch { alert('Error uploading image'); }
});

function renderLocList() {
  const el = document.getElementById('locationList');
  el.innerHTML = '';
  locations.forEach(loc => {
    const div = document.createElement('div');
    div.className = `item ${currentEditId === loc.id ? 'active' : ''}`;
    div.innerHTML = `<strong>${loc.name.es || loc.id}</strong><small>${loc.region}</small>`;
    div.onclick = () => openLocEditor(loc.id);
    el.appendChild(div);
  });
}

function populateZoneDropdown() {
  fZone.innerHTML = zones.map(z => `<option value="${z.id}">${z.name.es || z.id}</option>`).join('');
}

function openLocEditor(id) {
  currentEditId = id;
  const loc = locations.find(l => l.id === id);
  if (!loc) return;
  locForm.classList.remove('hidden'); locEmpty.classList.add('hidden');
  fId.value = loc.id; fId.disabled = true;
  fNameEn.value = loc.name.en || ''; fNameEs.value = loc.name.es || '';
  fZone.value = loc.region || '';
  fLat.value = loc.latitude || 0; fLng.value = loc.longitude || 0;
  fImage.value = loc.image || ''; fThumb.value = loc.thumbnail || '';
  fTipEn.value = loc.tip.en || ''; fTipEs.value = loc.tip.es || '';
  if (fImage.value) { imgPreview.src = fImage.value; imgPreviewC.style.display = 'block'; }
  else imgPreviewC.style.display = 'none';
  fImageUpload.value = '';
  renderLocList();
}

document.getElementById('addLocationBtn').onclick = () => {
  currentEditId = 'new_' + Date.now();
  locForm.classList.remove('hidden'); locEmpty.classList.add('hidden');
  fId.value = ''; fId.disabled = false;
  fNameEn.value = ''; fNameEs.value = '';
  fZone.value = zones.length ? zones[0].id : '';
  fLat.value = -33.4569; fLng.value = -70.6483;
  fImage.value = ''; fThumb.value = ''; fTipEn.value = ''; fTipEs.value = '';
  imgPreviewC.style.display = 'none'; fImageUpload.value = '';
  renderLocList();
};

document.getElementById('deleteLocationBtn').onclick = () => {
  if (!confirm('Delete this location?')) return;
  locations = locations.filter(l => l.id !== currentEditId);
  currentEditId = null;
  locForm.classList.add('hidden'); locEmpty.classList.remove('hidden');
  postJSON('/api/locations', locations); renderLocList();
};

locForm.onsubmit = async (e) => {
  e.preventDefault();
  const isNew = !fId.disabled;
  const id = fId.value.trim();
  const obj = {
    id, name: { en: fNameEn.value, es: fNameEs.value },
    region: fZone.value,
    latitude: parseFloat(fLat.value), longitude: parseFloat(fLng.value),
    image: fImage.value, thumbnail: fThumb.value,
    tip: { en: fTipEn.value, es: fTipEs.value },
    difficulty: [3, 4, 5, 6]
  };
  if (isNew) {
    if (locations.find(l => l.id === id)) { alert('ID already exists!'); return; }
    locations.push(obj); fId.disabled = true; currentEditId = id;
  } else {
    const idx = locations.findIndex(l => l.id === id);
    if (idx > -1) locations[idx] = obj;
  }
  await postJSON('/api/locations', locations); renderLocList();
};

// ============================================================
// ZONES
// ============================================================
const zoneForm = document.getElementById('zoneForm');
const zoneEmpty = document.getElementById('zoneEmpty');

function renderZoneList() {
  const el = document.getElementById('zoneList');
  el.innerHTML = '';
  zones.sort((a, b) => a.order - b.order).forEach(z => {
    const div = document.createElement('div');
    div.className = `item ${currentZoneId === z.id ? 'active' : ''}`;
    div.innerHTML = `<strong>${z.name.es || z.id}</strong><small>${z.requiredPoints} pts</small>`;
    div.onclick = () => openZoneEditor(z.id);
    el.appendChild(div);
  });
}

function openZoneEditor(id) {
  currentZoneId = id;
  const z = zones.find(x => x.id === id);
  if (!z) return;
  zoneForm.classList.remove('hidden'); zoneEmpty.classList.add('hidden');
  document.getElementById('zoneId').value = z.id;
  document.getElementById('zoneId').disabled = true;
  document.getElementById('zoneNameEn').value = z.name.en || '';
  document.getElementById('zoneNameEs').value = z.name.es || '';
  document.getElementById('zonePoints').value = z.requiredPoints;
  document.getElementById('zoneOrder').value = z.order;
  document.getElementById('zoneIcon').value = z.icon || 'landscape';
  renderZoneList();
}

document.getElementById('addZoneBtn').onclick = () => {
  currentZoneId = 'new_' + Date.now();
  zoneForm.classList.remove('hidden'); zoneEmpty.classList.add('hidden');
  const zId = document.getElementById('zoneId');
  zId.value = ''; zId.disabled = false;
  document.getElementById('zoneNameEn').value = '';
  document.getElementById('zoneNameEs').value = '';
  document.getElementById('zonePoints').value = 0;
  document.getElementById('zoneOrder').value = zones.length + 1;
  document.getElementById('zoneIcon').value = 'landscape';
  renderZoneList();
};

document.getElementById('deleteZoneBtn').onclick = () => {
  if (!confirm('Delete this zone?')) return;
  zones = zones.filter(z => z.id !== currentZoneId);
  currentZoneId = null;
  zoneForm.classList.add('hidden'); zoneEmpty.classList.remove('hidden');
  postJSON('/api/zones', zones); renderZoneList(); populateZoneDropdown();
};

zoneForm.onsubmit = async (e) => {
  e.preventDefault();
  const zId = document.getElementById('zoneId');
  const isNew = !zId.disabled;
  const id = zId.value.trim();
  const obj = {
    id, name: { en: document.getElementById('zoneNameEn').value, es: document.getElementById('zoneNameEs').value },
    requiredPoints: parseInt(document.getElementById('zonePoints').value),
    order: parseInt(document.getElementById('zoneOrder').value),
    icon: document.getElementById('zoneIcon').value
  };
  if (isNew) {
    if (zones.find(z => z.id === id)) { alert('Zone ID exists!'); return; }
    zones.push(obj); zId.disabled = true; currentZoneId = id;
  } else {
    const idx = zones.findIndex(z => z.id === id);
    if (idx > -1) zones[idx] = obj;
  }
  await postJSON('/api/zones', zones); renderZoneList(); populateZoneDropdown();
};

// ============================================================
// TROPHIES
// ============================================================
const trophyForm = document.getElementById('trophyForm');
const trophyEmpty = document.getElementById('trophyEmpty');

function renderTrophyList() {
  const el = document.getElementById('trophyList');
  el.innerHTML = '';
  trophies.forEach(t => {
    const div = document.createElement('div');
    div.className = `item ${currentTrophyId === t.id ? 'active' : ''}`;
    div.innerHTML = `<strong>${t.name.es || t.id}</strong><small>${t.type}</small>`;
    div.onclick = () => openTrophyEditor(t.id);
    el.appendChild(div);
  });
}

function openTrophyEditor(id) {
  currentTrophyId = id;
  const t = trophies.find(x => x.id === id);
  if (!t) return;
  trophyForm.classList.remove('hidden'); trophyEmpty.classList.add('hidden');
  document.getElementById('trophyId').value = t.id;
  document.getElementById('trophyId').disabled = true;
  document.getElementById('trophyNameEn').value = t.name.en || '';
  document.getElementById('trophyNameEs').value = t.name.es || '';
  document.getElementById('trophyDescEn').value = t.description.en || '';
  document.getElementById('trophyDescEs').value = t.description.es || '';
  document.getElementById('trophyIcon').value = t.icon || 'emoji_events';
  document.getElementById('trophyType').value = t.type || 'milestone';
  document.getElementById('trophyMetric').value = t.condition.metric || 'totalCompleted';
  document.getElementById('trophyThreshold').value = t.condition.threshold || t.condition.zoneId || '';
  renderTrophyList();
}

document.getElementById('addTrophyBtn').onclick = () => {
  currentTrophyId = 'new_' + Date.now();
  trophyForm.classList.remove('hidden'); trophyEmpty.classList.add('hidden');
  const tId = document.getElementById('trophyId');
  tId.value = ''; tId.disabled = false;
  document.getElementById('trophyNameEn').value = '';
  document.getElementById('trophyNameEs').value = '';
  document.getElementById('trophyDescEn').value = '';
  document.getElementById('trophyDescEs').value = '';
  document.getElementById('trophyIcon').value = 'emoji_events';
  document.getElementById('trophyType').value = 'milestone';
  document.getElementById('trophyMetric').value = 'totalCompleted';
  document.getElementById('trophyThreshold').value = '';
  renderTrophyList();
};

document.getElementById('deleteTrophyBtn').onclick = () => {
  if (!confirm('Delete this trophy?')) return;
  trophies = trophies.filter(t => t.id !== currentTrophyId);
  currentTrophyId = null;
  trophyForm.classList.add('hidden'); trophyEmpty.classList.remove('hidden');
  postJSON('/api/trophies', trophies); renderTrophyList();
};

trophyForm.onsubmit = async (e) => {
  e.preventDefault();
  const tId = document.getElementById('trophyId');
  const isNew = !tId.disabled;
  const id = tId.value.trim();
  const metric = document.getElementById('trophyMetric').value;
  const threshVal = document.getElementById('trophyThreshold').value;
  const condition = metric === 'zoneAllCompleted'
    ? { metric, zoneId: threshVal }
    : { metric, threshold: parseInt(threshVal) || 0 };
  const obj = {
    id, name: { en: document.getElementById('trophyNameEn').value, es: document.getElementById('trophyNameEs').value },
    description: { en: document.getElementById('trophyDescEn').value, es: document.getElementById('trophyDescEs').value },
    icon: document.getElementById('trophyIcon').value,
    type: document.getElementById('trophyType').value,
    condition
  };
  if (isNew) {
    if (trophies.find(t => t.id === id)) { alert('Trophy ID exists!'); return; }
    trophies.push(obj); tId.disabled = true; currentTrophyId = id;
  } else {
    const idx = trophies.findIndex(t => t.id === id);
    if (idx > -1) trophies[idx] = obj;
  }
  await postJSON('/api/trophies', trophies); renderTrophyList();
};

// ============================================================
// SCORING
// ============================================================
const scoringForm = document.getElementById('scoringForm');

function populateScoring() {
  document.getElementById('score3').value = scoring.basePoints?.['3'] || 50;
  document.getElementById('score4').value = scoring.basePoints?.['4'] || 100;
  document.getElementById('score5').value = scoring.basePoints?.['5'] || 200;
  document.getElementById('score6').value = scoring.basePoints?.['6'] || 350;
  document.getElementById('scoreTimeThreshold').value = scoring.timeBonusThresholdSecs || 60;
  document.getElementById('scoreTimeBonus').value = scoring.timeBonusPoints || 50;
  document.getElementById('scoreMoveBonus').value = scoring.moveEfficiencyBonusPercent || 20;
}

scoringForm.onsubmit = async (e) => {
  e.preventDefault();
  scoring = {
    basePoints: {
      '3': parseInt(document.getElementById('score3').value),
      '4': parseInt(document.getElementById('score4').value),
      '5': parseInt(document.getElementById('score5').value),
      '6': parseInt(document.getElementById('score6').value),
    },
    timeBonusThresholdSecs: parseInt(document.getElementById('scoreTimeThreshold').value),
    timeBonusPoints: parseInt(document.getElementById('scoreTimeBonus').value),
    moveEfficiencyBonusPercent: parseInt(document.getElementById('scoreMoveBonus').value),
  };
  await postJSON('/api/scoring', scoring);
  alert('Scoring saved!');
};

// ============================================================
// INIT
// ============================================================
async function init() {
  [locations, zones, trophies, scoring] = await Promise.all([
    fetchJSON('/api/locations'),
    fetchJSON('/api/zones'),
    fetchJSON('/api/trophies'),
    fetchJSON('/api/scoring'),
  ]);
  renderLocList(); renderZoneList(); renderTrophyList();
  populateZoneDropdown(); populateScoring();
}
init();
