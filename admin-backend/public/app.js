// --- API base (auto-detect /zoominchile prefix from URL) ---
const API_BASE = window.location.pathname.replace(/\/(admin\/?)?$/, '');

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
async function putJSON(url, data) {
  await fetch(url, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
}
async function deleteJSON(url) {
  await fetch(url, { method: 'DELETE' });
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
const fRequiredPoints = document.getElementById('locRequiredPoints');
const fCropX = document.getElementById('locCropX'), fCropY = document.getElementById('locCropY');
const fCropW = document.getElementById('locCropW'), fCropH = document.getElementById('locCropH');
const fGmapsLink = document.getElementById('locGmapsLink');
const fImageUpload = document.getElementById('locImageUpload');
const imgPreviewC = document.getElementById('imagePreviewContainer');
const imgPreview = document.getElementById('imagePreview');

// --- Map picker (Leaflet + OpenStreetMap) ---
let locMap = null, locMarker = null;

function initMap() {
  if (locMap) return;
  locMap = L.map('locMap').setView([-33.45, -70.65], 5);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
    maxZoom: 19
  }).addTo(locMap);
  locMarker = L.marker([-33.45, -70.65], { draggable: true }).addTo(locMap);
  locMap.on('click', (e) => {
    locMarker.setLatLng(e.latlng);
    fLat.value = e.latlng.lat.toFixed(7);
    fLng.value = e.latlng.lng.toFixed(7);
    updateGmapsLink();
  });
  locMarker.on('dragend', () => {
    const pos = locMarker.getLatLng();
    fLat.value = pos.lat.toFixed(7);
    fLng.value = pos.lng.toFixed(7);
    updateGmapsLink();
  });
}

function updateGmapsLink() {
  const lat = parseFloat(fLat.value) || -33.45;
  const lng = parseFloat(fLng.value) || -70.65;
  fGmapsLink.href = `https://www.google.com/maps?q=${lat},${lng}`;
}

function updateMapFromFields() {
  if (!locMap) return;
  const lat = parseFloat(fLat.value) || -33.45;
  const lng = parseFloat(fLng.value) || -70.65;
  locMarker.setLatLng([lat, lng]);
  locMap.setView([lat, lng], Math.max(locMap.getZoom(), 12));
  updateGmapsLink();
}

// --- Required points suggestions per zone ---
const POINTS_BY_ZONE = {
  easy:   [0, 50, 100, 150],
  normal: [200, 500, 750, 1000],
  hard:   [800, 1500, 2000, 3000],
  expert: [2500, 3500, 5000, 7500],
  insane: [5000, 7500, 10000, 15000],
};

function populatePointsDropdown(zone, currentValue) {
  const opts = POINTS_BY_ZONE[zone] || [0, 100, 500, 1000, 2000, 5000];
  // Include current value if not in the list
  const values = [...new Set([...opts, ...(currentValue != null ? [currentValue] : [])])].sort((a, b) => a - b);
  fRequiredPoints.innerHTML = values.map(v => `<option value="${v}"${v === currentValue ? ' selected' : ''}>${v} pts</option>`).join('');
}

fZone.addEventListener('change', () => {
  populatePointsDropdown(fZone.value, parseInt(fRequiredPoints.value) || 0);
});

fNameEn.addEventListener('input', () => {
  if (!fId.disabled) {
    fId.value = fNameEn.value.toLowerCase().trim()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
  }
});

fImageUpload.addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  const fd = new FormData(); fd.append('image', file);
  try {
    const r = await fetch(API_BASE + '/api/upload', { method: 'POST', body: fd });
    const d = await r.json();
    if (d.url) {
      fImage.value = d.url;
      fThumb.value = d.thumbnail || d.url;
      imgPreview.src = d.url; imgPreviewC.style.display = 'block';
      cropToolLoad(d.url);
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
  populatePointsDropdown(loc.region || '', loc.requiredPoints || 0);
  fRequiredPoints.value = loc.requiredPoints || 0;
  fLat.value = loc.latitude || 0; fLng.value = loc.longitude || 0;
  initMap();
  setTimeout(() => { locMap.invalidateSize(); updateMapFromFields(); }, 100);
  fImage.value = loc.image || ''; fThumb.value = loc.thumbnail || '';
  fTipEn.value = loc.tip.en || ''; fTipEs.value = loc.tip.es || '';
  const crop = loc.crop || {};
  fCropX.value = crop.x ?? 0.15; fCropY.value = crop.y ?? 0.15;
  fCropW.value = crop.w ?? 0.7; fCropH.value = crop.h ?? 0.7;
  if (fImage.value) { imgPreview.src = fImage.value; cropToolLoad(fImage.value); }
  else { imgPreviewC.style.display = 'none'; cropToolHide(); }
  fImageUpload.value = '';
  renderLocList();
}

document.getElementById('addLocationBtn').onclick = () => {
  currentEditId = 'new_' + Date.now();
  locForm.classList.remove('hidden'); locEmpty.classList.add('hidden');
  fId.value = ''; fId.disabled = false;
  fNameEn.value = ''; fNameEs.value = '';
  fZone.value = zones.length ? zones[0].id : '';
  populatePointsDropdown(fZone.value, 0);
  fRequiredPoints.value = 0;
  fLat.value = -33.4569; fLng.value = -70.6483;
  initMap();
  setTimeout(() => { locMap.invalidateSize(); updateMapFromFields(); }, 100);
  fImage.value = ''; fThumb.value = ''; fTipEn.value = ''; fTipEs.value = '';
  fCropX.value = 0.15; fCropY.value = 0.15; fCropW.value = 0.7; fCropH.value = 0.7;
  imgPreviewC.style.display = 'none'; fImageUpload.value = '';
  cropToolHide();
  renderLocList();
};

document.getElementById('deleteLocationBtn').onclick = async () => {
  if (!confirm('Delete this location?')) return;
  await deleteJSON(API_BASE + '/api/locations/' + currentEditId);
  locations = locations.filter(l => l.id !== currentEditId);
  currentEditId = null;
  locForm.classList.add('hidden'); locEmpty.classList.remove('hidden');
  renderLocList();
};

locForm.onsubmit = async (e) => {
  e.preventDefault();
  const isNew = !fId.disabled;
  const id = fId.value.trim();
  const obj = {
    id, name: { en: fNameEn.value, es: fNameEs.value },
    region: fZone.value,
    requiredPoints: parseInt(fRequiredPoints.value) || 0,
    latitude: parseFloat(fLat.value), longitude: parseFloat(fLng.value),
    image: fImage.value, thumbnail: fThumb.value,
    tip: { en: fTipEn.value, es: fTipEs.value },
    crop: { x: parseFloat(fCropX.value), y: parseFloat(fCropY.value), w: parseFloat(fCropW.value), h: parseFloat(fCropH.value) },
    difficulty: [3, 4, 5, 6]
  };
  if (isNew) {
    if (locations.find(l => l.id === id)) { alert('ID already exists!'); return; }
    await postJSON(API_BASE + '/api/locations', obj);
    locations.push(obj); fId.disabled = true; currentEditId = id;
  } else {
    await putJSON(API_BASE + '/api/locations/' + id, obj);
    const idx = locations.findIndex(l => l.id === id);
    if (idx > -1) locations[idx] = obj;
  }
  renderLocList();
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
    div.innerHTML = `<strong>${z.name.es || z.id}</strong><small>Order: ${z.order}</small>`;
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
  document.getElementById('zoneOrder').value = zones.length + 1;
  document.getElementById('zoneIcon').value = 'landscape';
  renderZoneList();
};

document.getElementById('deleteZoneBtn').onclick = () => {
  if (!confirm('Delete this zone?')) return;
  zones = zones.filter(z => z.id !== currentZoneId);
  currentZoneId = null;
  zoneForm.classList.add('hidden'); zoneEmpty.classList.remove('hidden');
  postJSON(API_BASE + '/api/zones', zones); renderZoneList(); populateZoneDropdown();
};

zoneForm.onsubmit = async (e) => {
  e.preventDefault();
  const zId = document.getElementById('zoneId');
  const isNew = !zId.disabled;
  const id = zId.value.trim();
  const obj = {
    id, name: { en: document.getElementById('zoneNameEn').value, es: document.getElementById('zoneNameEs').value },
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
  await postJSON(API_BASE + '/api/zones', zones); renderZoneList(); populateZoneDropdown();
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
  postJSON(API_BASE + '/api/trophies', trophies); renderTrophyList();
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
  await postJSON(API_BASE + '/api/trophies', trophies); renderTrophyList();
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
  await postJSON(API_BASE + '/api/scoring', scoring);
  alert('Scoring saved!');
};

// ============================================================
// VISUAL CROP TOOL + DIFFICULTY PREVIEWS
// ============================================================
const cropCanvas = document.getElementById('cropCanvas');
const cropCtx = cropCanvas.getContext('2d');
const cropContainer = document.getElementById('cropToolContainer');
const cropNoImage = document.getElementById('cropNoImage');
const cropPreviews = document.getElementById('cropPreviews');
let cropImg = null;
let cropScale = 1;
let cropDrag = null;

// Difficulty interpolation (mirrors Flutter getCropForDifficulty)
// t=0 → admin crop (easy), t=1 → full image (expert)
function interpolateCrop(t) {
  const cx = parseFloat(fCropX.value) || 0;
  const cy = parseFloat(fCropY.value) || 0;
  const cw = parseFloat(fCropW.value) || 0.7;
  const ch = parseFloat(fCropH.value) || 0.7;
  return {
    x: cx * (1 - t),
    y: cy * (1 - t),
    w: cw + (1 - cw) * t,
    h: ch + (1 - ch) * t,
  };
}

// Phone aspect ratio for crop region (9:16 portrait)
const PHONE_RATIO = 16 / 9; // h/w in normalized coords relative to image

function cropToolHide() {
  cropContainer.style.display = 'none';
  cropPreviews.style.display = 'none';
  cropNoImage.style.display = 'block';
  imgPreviewC.style.display = 'none';
  cropImg = null;
}

function cropToolLoad(url) {
  const img = new Image();
  img.crossOrigin = 'anonymous';
  img.onload = () => {
    cropImg = img;
    cropNoImage.style.display = 'none';
    imgPreviewC.style.display = 'none'; // hide redundant preview
    cropContainer.style.display = 'block';
    cropPreviews.style.display = 'block';
    cropToolResize();
    cropToolDraw();
  };
  img.onerror = () => { cropToolHide(); if (fImage.value) { imgPreviewC.style.display = 'block'; } };
  img.src = url;
}

function cropToolResize() {
  if (!cropImg) return;
  const maxW = cropContainer.clientWidth || 500;
  const ratio = cropImg.naturalHeight / cropImg.naturalWidth;
  // Cap height at 350px
  const maxH = 350;
  let cssW = maxW;
  let cssH = maxW * ratio;
  if (cssH > maxH) { cssH = maxH; cssW = maxH / ratio; }
  const dpr = window.devicePixelRatio || 1;
  cropCanvas.style.width = cssW + 'px';
  cropCanvas.style.height = cssH + 'px';
  cropCanvas.width = cssW * dpr;
  cropCanvas.height = cssH * dpr;
  cropScale = dpr;
  cropCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function cropGetRect() {
  const cw = cropCanvas.width / cropScale;
  const ch = cropCanvas.height / cropScale;
  const x = parseFloat(fCropX.value) || 0;
  const y = parseFloat(fCropY.value) || 0;
  const w = parseFloat(fCropW.value) || 0.5;
  const h = parseFloat(fCropH.value) || 0.5;
  return { px: x * cw, py: y * ch, pw: w * cw, ph: h * ch, cw, ch };
}

function cropToolDraw() {
  if (!cropImg) return;
  const cw = cropCanvas.width / cropScale;
  const ch = cropCanvas.height / cropScale;
  cropCtx.clearRect(0, 0, cw, ch);
  cropCtx.drawImage(cropImg, 0, 0, cw, ch);

  const r = cropGetRect();
  // Dim outside
  cropCtx.fillStyle = 'rgba(0,0,0,0.55)';
  cropCtx.fillRect(0, 0, cw, r.py);
  cropCtx.fillRect(0, r.py + r.ph, cw, ch - r.py - r.ph);
  cropCtx.fillRect(0, r.py, r.px, r.ph);
  cropCtx.fillRect(r.px + r.pw, r.py, cw - r.px - r.pw, r.ph);

  // Border
  cropCtx.strokeStyle = '#238636';
  cropCtx.lineWidth = 2;
  cropCtx.strokeRect(r.px, r.py, r.pw, r.ph);

  // Corner handles
  const hs = 8;
  cropCtx.fillStyle = '#238636';
  for (const [cx, cy] of [[r.px, r.py], [r.px + r.pw, r.py], [r.px, r.py + r.ph], [r.px + r.pw, r.py + r.ph]]) {
    cropCtx.fillRect(cx - hs / 2, cy - hs / 2, hs, hs);
  }

  // Rule-of-thirds
  cropCtx.strokeStyle = 'rgba(255,255,255,0.2)';
  cropCtx.lineWidth = 0.5;
  for (let i = 1; i <= 2; i++) {
    cropCtx.beginPath();
    cropCtx.moveTo(r.px + r.pw * i / 3, r.py);
    cropCtx.lineTo(r.px + r.pw * i / 3, r.py + r.ph);
    cropCtx.stroke();
    cropCtx.beginPath();
    cropCtx.moveTo(r.px, r.py + r.ph * i / 3);
    cropCtx.lineTo(r.px + r.pw, r.py + r.ph * i / 3);
    cropCtx.stroke();
  }

  // "EASY" label
  cropCtx.fillStyle = '#238636';
  cropCtx.font = 'bold 11px Outfit, sans-serif';
  cropCtx.fillText('EASY', r.px + 6, r.py + 16);

  // Draw difficulty preview thumbnails
  drawCropPreviews();
}

function drawCropPreviews() {
  if (!cropImg) return;
  const diffs = [
    { id: 'prevEasy',   t: 0,     color: '#238636' },
    { id: 'prevNormal', t: 1 / 3, color: '#d29922' },
    { id: 'prevHard',   t: 2 / 3, color: '#58a6ff' },
    { id: 'prevExpert', t: 1,     color: '#bc8cff' },
  ];
  const natW = cropImg.naturalWidth;
  const natH = cropImg.naturalHeight;
  // Fixed phone-shaped preview: 80px wide, 9:16 ratio
  const prevW = 80;
  const prevH = Math.round(prevW * PHONE_RATIO);
  const dpr = window.devicePixelRatio || 1;

  for (const d of diffs) {
    const canvas = document.getElementById(d.id);
    if (!canvas) continue;
    const crop = interpolateCrop(d.t);
    const sx = crop.x * natW;
    const sy = crop.y * natH;
    const sw = crop.w * natW;
    const sh = crop.h * natH;
    canvas.style.width = prevW + 'px';
    canvas.style.height = prevH + 'px';
    canvas.width = prevW * dpr;
    canvas.height = prevH * dpr;
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#111';
    ctx.fillRect(0, 0, prevW, prevH);
    ctx.drawImage(cropImg, sx, sy, sw, sh, 0, 0, prevW, prevH);
    // Rounded border
    ctx.strokeStyle = d.color;
    ctx.lineWidth = 2;
    ctx.strokeRect(1, 1, prevW - 2, prevH - 2);
  }
}

function cropHitTest(mx, my) {
  const r = cropGetRect();
  const edge = 12;
  const onLeft = Math.abs(mx - r.px) < edge;
  const onRight = Math.abs(mx - (r.px + r.pw)) < edge;
  const onTop = Math.abs(my - r.py) < edge;
  const onBottom = Math.abs(my - (r.py + r.ph)) < edge;
  const inX = mx > r.px + edge && mx < r.px + r.pw - edge;
  const inY = my > r.py + edge && my < r.py + r.ph - edge;

  if (onTop && onLeft) return 'nw';
  if (onTop && onRight) return 'ne';
  if (onBottom && onLeft) return 'sw';
  if (onBottom && onRight) return 'se';
  if (onTop && inX) return 'n';
  if (onBottom && inX) return 's';
  if (onLeft && inY) return 'w';
  if (onRight && inY) return 'e';
  if (mx > r.px && mx < r.px + r.pw && my > r.py && my < r.py + r.ph) return 'move';
  return null;
}

function cropCursorFor(type) {
  if (!type) return 'crosshair';
  if (type === 'move') return 'grab';
  if (type === 'nw' || type === 'se') return 'nwse-resize';
  if (type === 'ne' || type === 'sw') return 'nesw-resize';
  if (type === 'n' || type === 's') return 'ns-resize';
  return 'ew-resize';
}

function cropCanvasXY(e) {
  const rect = cropCanvas.getBoundingClientRect();
  const touch = e.touches ? e.touches[0] : e;
  return { x: touch.clientX - rect.left, y: touch.clientY - rect.top };
}

function cropSetValues(x, y, w, h) {
  w = Math.max(0.08, Math.min(1, w));
  // Enforce phone aspect ratio: h = w * PHONE_RATIO * (imgW / imgH)
  if (cropImg) {
    h = w * PHONE_RATIO * (cropImg.naturalWidth / cropImg.naturalHeight);
  }
  h = Math.max(0.08, Math.min(1, h));
  // If h was clamped to 1, recalculate w from h
  if (cropImg && h >= 1) {
    h = 1;
    w = h / (PHONE_RATIO * (cropImg.naturalWidth / cropImg.naturalHeight));
  }
  x = Math.max(0, Math.min(1 - w, x));
  y = Math.max(0, Math.min(1 - h, y));
  fCropX.value = x.toFixed(2);
  fCropY.value = y.toFixed(2);
  fCropW.value = w.toFixed(2);
  fCropH.value = h.toFixed(2);
  cropToolDraw();
}

function cropStartDrag(e) {
  e.preventDefault();
  const { x, y } = cropCanvasXY(e);
  const hit = cropHitTest(x, y);
  if (!hit) {
    // Click outside = new crop centered here
    const cw = cropCanvas.width / cropScale;
    const ch = cropCanvas.height / cropScale;
    const nx = x / cw;
    const ny = y / ch;
    cropDrag = {
      type: 'se', startX: x, startY: y,
      origCrop: { x: nx, y: ny, w: 0.08, h: 0.08 }
    };
    cropSetValues(nx, ny, 0.15, 0);
    return;
  }
  cropDrag = {
    type: hit, startX: x, startY: y,
    origCrop: {
      x: parseFloat(fCropX.value), y: parseFloat(fCropY.value),
      w: parseFloat(fCropW.value), h: parseFloat(fCropH.value),
    }
  };
  if (hit === 'move') cropCanvas.style.cursor = 'grabbing';
}

function cropMoveDrag(e) {
  if (!cropImg) return;
  const { x, y } = cropCanvasXY(e);
  if (!cropDrag) {
    cropCanvas.style.cursor = cropCursorFor(cropHitTest(x, y));
    return;
  }
  e.preventDefault();
  const cw = cropCanvas.width / cropScale;
  const ch = cropCanvas.height / cropScale;
  const dx = (x - cropDrag.startX) / cw;
  const dy = (y - cropDrag.startY) / ch;
  const o = cropDrag.origCrop;

  let nx = o.x, ny = o.y, nw = o.w;
  const t = cropDrag.type;
  if (t === 'move') { nx = o.x + dx; ny = o.y + dy; }
  else {
    // All resize handles → uniform scale via width delta
    if (t.includes('w')) { nx = o.x + dx; nw = o.w - dx; }
    else if (t.includes('e')) { nw = o.w + dx; }
    else if (t.includes('n') || t.includes('s')) { nw = o.w - dy; } // vertical drag also scales width
  }
  cropSetValues(nx, ny, nw, 0); // h is auto from aspect ratio
}

function cropEndDrag() {
  if (cropDrag && cropDrag.type === 'move') cropCanvas.style.cursor = 'grab';
  cropDrag = null;
}

cropCanvas.addEventListener('mousedown', cropStartDrag);
window.addEventListener('mousemove', cropMoveDrag);
window.addEventListener('mouseup', cropEndDrag);
cropCanvas.addEventListener('touchstart', cropStartDrag, { passive: false });
window.addEventListener('touchmove', cropMoveDrag, { passive: false });
window.addEventListener('touchend', cropEndDrag);

// ============================================================
// TESTERS
// ============================================================
let testers = [];

function renderTesterTable() {
  const tbody = document.getElementById('testerTableBody');
  const empty = document.getElementById('testerEmpty');
  const stats = document.getElementById('testerStats');
  tbody.innerHTML = '';
  if (!testers.length) { empty.style.display = 'block'; stats.textContent = ''; return; }
  empty.style.display = 'none';
  const enrolled = testers.filter(t => t.enrolled).length;
  const notified = testers.filter(t => t.notified).length;
  stats.textContent = `${testers.length} total · ${enrolled} enrolled · ${notified} notified`;

  testers.forEach(t => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${esc(t.name)}</td>
      <td>${esc(t.email)}</td>
      <td>${t.lang.toUpperCase()}</td>
      <td><input type="checkbox" ${t.enrolled ? 'checked' : ''} data-id="${t.id}" data-field="enrolled"></td>
      <td><span class="tester-badge ${t.notified ? 'yes' : 'no'}">${t.notified ? 'Yes' : 'No'}</span></td>
      <td style="white-space:nowrap;">
        <select class="notify-lang" data-id="${t.id}" style="width:auto;padding:0.3rem;font-size:0.75rem;display:inline-block;vertical-align:middle;">
          <option value="es" ${t.lang === 'es' ? 'selected' : ''}>ES</option>
          <option value="en" ${t.lang === 'en' ? 'selected' : ''}>EN</option>
        </select>
        <button class="btn-notify-one" data-id="${t.id}" title="Send notification" style="background:var(--accent);color:white;border:none;padding:0.3rem 0.6rem;border-radius:4px;font-size:0.75rem;cursor:pointer;vertical-align:middle;">Send</button>
      </td>
      <td><button class="btn-delete" data-delete-id="${t.id}" title="Delete">✕</button></td>
    `;
    tbody.appendChild(tr);
  });

  // Bind checkbox toggles
  tbody.querySelectorAll('input[type="checkbox"]').forEach(cb => {
    cb.onchange = async () => {
      const id = cb.dataset.id;
      try {
        await putJSON(API_BASE + '/api/testers/' + id, { enrolled: cb.checked ? 1 : 0 });
        const t = testers.find(x => x.id == id);
        if (t) t.enrolled = cb.checked;
        renderTesterTable();
      } catch { showTesterMsg('Error updating tester', true); }
    };
  });

  // Bind individual notify buttons
  tbody.querySelectorAll('.btn-notify-one').forEach(btn => {
    btn.onclick = async () => {
      const id = btn.dataset.id;
      const lang = tbody.querySelector(`.notify-lang[data-id="${id}"]`).value;
      btn.disabled = true; btn.textContent = '...';
      try {
        const res = await fetch(API_BASE + '/api/testers/' + id + '/notify', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ lang }),
        });
        const data = await res.json();
        if (res.ok) {
          showTesterMsg('Notification sent', false);
          testers = await fetchJSON(API_BASE + '/api/testers');
          renderTesterTable();
        } else {
          showTesterMsg(data.error || 'Error sending', true);
        }
      } catch { showTesterMsg('Error sending notification', true); }
      btn.disabled = false; btn.textContent = 'Send';
    };
  });

  // Bind delete buttons
  tbody.querySelectorAll('.btn-delete').forEach(btn => {
    btn.onclick = async () => {
      if (!confirm('Delete this tester?')) return;
      const id = btn.dataset.deleteId;
      try {
        await deleteJSON(API_BASE + '/api/testers/' + id);
        testers = testers.filter(t => t.id != id);
        renderTesterTable();
      } catch { showTesterMsg('Error deleting tester', true); }
    };
  });
}

function esc(s) {
  const d = document.createElement('div');
  d.textContent = s || '';
  return d.innerHTML;
}

function showTesterMsg(text, isError) {
  const el = document.getElementById('testerMsg');
  el.textContent = text;
  el.style.display = 'block';
  el.style.background = isError ? 'rgba(248,81,73,0.15)' : 'rgba(35,134,54,0.15)';
  el.style.color = isError ? '#f85149' : '#3fb950';
  setTimeout(() => { el.style.display = 'none'; }, 5000);
}

document.getElementById('refreshTestersBtn').onclick = async () => {
  const btn = document.getElementById('refreshTestersBtn');
  btn.disabled = true; btn.textContent = '...';
  try {
    testers = await fetchJSON(API_BASE + '/api/testers');
    renderTesterTable();
    showTesterMsg('Refreshed', false);
  } catch { showTesterMsg('Error refreshing', true); }
  btn.disabled = false; btn.textContent = 'Refresh';
};

document.getElementById('notifyTestersBtn').onclick = async () => {
  const btn = document.getElementById('notifyTestersBtn');
  const enrolled = testers.filter(t => t.enrolled && !t.notified);
  if (!enrolled.length) { showTesterMsg('No enrolled testers pending notification', true); return; }
  if (!confirm(`Send notification email to ${enrolled.length} tester(s)?`)) return;
  btn.disabled = true; btn.textContent = 'Sending...';
  try {
    const res = await fetch(API_BASE + '/api/testers/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' } });
    const data = await res.json();
    if (res.ok) {
      showTesterMsg(`Notified ${data.sent} tester(s)`, false);
      testers = await fetchJSON(API_BASE + '/api/testers');
      renderTesterTable();
    } else {
      showTesterMsg(data.error || 'Error sending notifications', true);
    }
  } catch { showTesterMsg('Error sending notifications', true); }
  btn.disabled = false; btn.textContent = 'Notify Enrolled';
};

// ============================================================
// INIT
// ============================================================
async function init() {
  const [locResult, zonesResult, trophiesResult, scoringResult, testersResult] = await Promise.all([
    fetchJSON(API_BASE + '/api/locations'),
    fetchJSON(API_BASE + '/api/zones'),
    fetchJSON(API_BASE + '/api/trophies'),
    fetchJSON(API_BASE + '/api/scoring'),
    fetchJSON(API_BASE + '/api/testers'),
  ]);
  // Support both paginated {data:[...]} and legacy array responses
  locations = Array.isArray(locResult) ? locResult : (locResult.data || []);
  zones = zonesResult;
  trophies = trophiesResult;
  scoring = scoringResult;
  testers = testersResult;
  renderLocList(); renderZoneList(); renderTrophyList(); renderTesterTable();
  populateZoneDropdown(); populateScoring();
}
init();
