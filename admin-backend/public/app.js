let locations = [];
let currentEditId = null;

const locationListEl = document.getElementById('locationList');
const editorForm = document.getElementById('editorForm');
const emptyState = document.getElementById('emptyState');

const fId = document.getElementById('locId');
const fNameEn = document.getElementById('locNameEn');
const fNameEs = document.getElementById('locNameEs');
const fRegion = document.getElementById('locRegion');
const fLat = document.getElementById('locLat');
const fLng = document.getElementById('locLng');
const fImage = document.getElementById('locImage');
const fThumb = document.getElementById('locThumbnail');
const fTipEn = document.getElementById('locTipEn');
const fTipEs = document.getElementById('locTipEs');

async function loadData() {
    try {
        const res = await fetch('/api/locations');
        locations = await res.json();
        renderList();
    } catch (e) {
        console.error('Failed to load JSON');
    }
}

async function saveData() {
    try {
        await fetch('/api/locations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(locations)
        });
        alert('Saved! Game app will now see these changes.');
    } catch (e) {
        alert('Error saving data');
    }
}

function renderList() {
    locationListEl.innerHTML = '';
    locations.forEach(loc => {
        const div = document.createElement('div');
        div.className = `location-item ${currentEditId === loc.id ? 'active' : ''}`;
        div.innerHTML = `<span><strong>${loc.name.es || loc.id}</strong></span><small>${loc.region}</small>`;
        div.onclick = () => openEditor(loc.id);
        locationListEl.appendChild(div);
    });
}

function openEditor(id) {
    currentEditId = id;
    const loc = locations.find(l => l.id === id);
    if (!loc) return;
    
    editorForm.classList.remove('hidden');
    emptyState.classList.add('hidden');
    
    fId.value = loc.id;
    fId.disabled = true;
    fNameEn.value = loc.name.en || '';
    fNameEs.value = loc.name.es || '';
    fRegion.value = loc.region || '';
    fLat.value = loc.latitude || 0;
    fLng.value = loc.longitude || 0;
    fImage.value = loc.image || '';
    fThumb.value = loc.thumbnail || '';
    fTipEn.value = loc.tip.en || '';
    fTipEs.value = loc.tip.es || '';
    
    renderList();
}

document.getElementById('addLocationBtn').onclick = () => {
    currentEditId = 'new_' + Date.now();
    editorForm.classList.remove('hidden');
    emptyState.classList.add('hidden');
    
    fId.value = '';
    fId.disabled = false;
    fNameEn.value = '';
    fNameEs.value = '';
    fRegion.value = '';
    fLat.value = -33.4569;
    fLng.value = -70.6483; // default Santiago
    fImage.value = '';
    fThumb.value = '';
    fTipEn.value = '';
    fTipEs.value = '';
    
    renderList();
};

document.getElementById('deleteLocationBtn').onclick = () => {
    if(confirm('Delete this location?')) {
        locations = locations.filter(l => l.id !== currentEditId);
        currentEditId = null;
        editorForm.classList.add('hidden');
        emptyState.classList.remove('hidden');
        saveData();
        renderList();
    }
};

editorForm.onsubmit = (e) => {
    e.preventDefault();
    
    let isNew = !fId.disabled;
    let actualId = fId.value.trim();
    
    const newObj = {
        id: actualId,
        name: { en: fNameEn.value, es: fNameEs.value },
        region: fRegion.value,
        latitude: parseFloat(fLat.value),
        longitude: parseFloat(fLng.value),
        image: fImage.value,
        thumbnail: fThumb.value,
        tip: { en: fTipEn.value, es: fTipEs.value },
        difficulty: [3, 4, 5, 6]
    };

    if (isNew) {
        if(locations.find(l => l.id === actualId)) {
            alert('ID already exists!'); return;
        }
        locations.push(newObj);
        fId.disabled = true;
        currentEditId = actualId;
    } else {
        const idx = locations.findIndex(l => l.id === actualId);
        if (idx > -1) locations[idx] = newObj;
    }

    saveData().then(() => renderList());
};

loadData();
