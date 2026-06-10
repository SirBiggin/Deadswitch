// Auto-generated from assets/web/index.html — do not edit manually
const String kWebPortalHtml = r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DeadSwitch Portal</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; background: #0f0f0f; color: #e0e0e0; min-height: 100vh; }

    nav { background: #1a1a1a; border-bottom: 1px solid #2a2a2a; padding: 0 1rem; display: flex; align-items: center; height: 52px; }
    .brand { font-weight: 700; font-size: 1.05rem; color: #fff; margin-right: 1.5rem; white-space: nowrap; }
    .nav-tab { padding: 0 1rem; height: 52px; display: flex; align-items: center; color: #777; font-size: 0.88rem; cursor: pointer; border-bottom: 2px solid transparent; white-space: nowrap; }
    .nav-tab:hover { color: #ccc; }
    .nav-tab.active { color: #7eb8f7; border-bottom-color: #7eb8f7; }

    .container { max-width: 820px; margin: 0 auto; padding: 1.5rem 1rem; }
    .page-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.25rem; }
    .page-title { font-size: 1.2rem; font-weight: 700; color: #fff; }

    .card { background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 10px; padding: 1.25rem; margin-bottom: 1rem; }
    .section-label { font-size: 0.75rem; color: #666; font-weight: 600; letter-spacing: 0.8px; margin-bottom: 0.9rem; }

    .btn { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.48rem 0.9rem; border-radius: 6px; border: none; cursor: pointer; font-size: 0.86rem; font-family: inherit; font-weight: 500; transition: opacity 0.15s; }
    .btn:hover:not(:disabled) { opacity: 0.82; }
    .btn:disabled { opacity: 0.4; cursor: default; }
    .btn-primary { background: #2563eb; color: #fff; }
    .btn-ghost   { background: #242424; color: #bbb; border: 1px solid #333; }
    .btn-danger  { background: #2b1010; color: #c87e7e; border: 1px solid #5a2020; }
    .btn-green   { background: #0f2b0f; color: #7ec87e; border: 1px solid #2d5a2d; }
    .btn-sm { padding: 0.3rem 0.65rem; font-size: 0.79rem; }

    .field { margin-bottom: 0.85rem; }
    label { display: block; font-size: 0.79rem; color: #888; margin-bottom: 0.28rem; }
    input[type=text], input[type=tel], input[type=password], textarea {
      width: 100%; padding: 0.52rem 0.7rem;
      background: #111; border: 1px solid #2e2e2e; border-radius: 6px;
      color: #e0e0e0; font-size: 0.9rem; font-family: inherit;
    }
    input:focus, textarea:focus { outline: none; border-color: #2563eb; }
    textarea { resize: vertical; min-height: 90px; }

    .overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.82); z-index: 200; align-items: flex-start; justify-content: center; padding: 5vh 1rem 2rem; overflow-y: auto; }
    .overlay.open { display: flex; }
    .modal { background: #1a1a1a; border: 1px solid #333; border-radius: 12px; width: 100%; max-width: 500px; padding: 1.5rem; }
    .modal-title { font-size: 1rem; font-weight: 700; color: #fff; margin-bottom: 1.25rem; }
    .modal-actions { display: flex; gap: 0.5rem; justify-content: flex-end; margin-top: 1.25rem; }

    #pin-overlay { display: flex; position: fixed; inset: 0; background: #0f0f0f; z-index: 300; align-items: center; justify-content: center; }
    .pin-box { background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 14px; padding: 2rem 1.75rem; width: min(94vw, 360px); text-align: center; }
    .pin-skull { font-size: 2.2rem; margin-bottom: 0.5rem; }
    .pin-title { font-size: 1.25rem; font-weight: 700; color: #fff; margin-bottom: 0.3rem; }
    .pin-sub { font-size: 0.82rem; color: #666; margin-bottom: 1.25rem; }
    #pin-error { color: #c87e7e; font-size: 0.8rem; margin-top: 0.6rem; display: none; }

    .item-row { display: flex; align-items: flex-start; gap: 0.9rem; padding: 0.9rem 0; border-bottom: 1px solid #1e1e1e; }
    .item-row:last-child { border-bottom: none; }
    .item-info { flex: 1; min-width: 0; }
    .item-name { color: #fff; font-weight: 600; font-size: 0.95rem; }
    .item-recipients { display: flex; align-items: center; gap: 0.3rem; margin-top: 0.25rem; color: #2563eb; font-size: 0.8rem; }
    .item-msg  { color: #555; font-size: 0.82rem; margin-top: 0.4rem; background: #111; padding: 0.45rem 0.65rem; border-radius: 5px; border: 1px solid #1e1e1e; white-space: pre-wrap; word-break: break-word; }
    .item-actions { display: flex; gap: 0.35rem; flex-shrink: 0; padding-top: 0.05rem; }

    .rec-row { display: flex; align-items: center; gap: 0.5rem; padding: 0.4rem 0.65rem; background: #111; border-radius: 6px; border: 1px solid #1e1e1e; margin-bottom: 6px; }
    .rec-info { flex: 1; }
    .rec-name  { color: #e0e0e0; font-size: 0.88rem; }
    .rec-phone { color: #666; font-size: 0.78rem; }
    .btn-rm { background: none; border: none; color: #555; cursor: pointer; font-size: 0.95rem; padding: 0 0.2rem; line-height: 1; }
    .btn-rm:hover { color: #c87e7e; }

    .add-rec-form { display: none; background: #111; border: 1px solid #252525; border-radius: 6px; padding: 0.7rem; margin-top: 0.5rem; }
    .add-rec-form.open { display: block; }
    .add-rec-row { display: flex; gap: 0.4rem; align-items: flex-end; }
    .add-rec-row input { flex: 1; }

    /* Contact picker */
    #contacts-overlay { z-index: 300; }
    #contacts-overlay .modal { max-width: 420px; max-height: 80vh; display: flex; flex-direction: column; padding: 1.25rem; }
    #contacts-search { margin-bottom: 0.75rem; }
    #contacts-list { overflow-y: auto; flex: 1; }
    .contact-item { padding: 0.55rem 0.5rem; border-radius: 6px; cursor: pointer; }
    .contact-item:hover { background: #242424; }
    .contact-item-name { color: #e0e0e0; font-size: 0.9rem; }
    .contact-item-phone { color: #666; font-size: 0.78rem; margin-top: 0.1rem; }
    .contact-phones { padding: 0.25rem 0 0.25rem 0.75rem; }
    .contact-phone-opt { padding: 0.4rem 0.5rem; border-radius: 5px; cursor: pointer; color: #7eb8f7; font-size: 0.85rem; }
    .contact-phone-opt:hover { background: #1a2a3a; }
    .contacts-loading { color: #555; text-align: center; padding: 2rem; }

    .alert { padding: 0.6rem 0.85rem; border-radius: 6px; font-size: 0.8rem; font-family: monospace; white-space: pre-wrap; word-break: break-all; margin-top: 0.75rem; }
    .alert-ok  { background: #0c280c; border: 1px solid #295229; color: #7ec87e; }
    .alert-err { background: #280c0c; border: 1px solid #522929; color: #c87e7e; }

    .empty { text-align: center; color: #555; padding: 3rem 1rem; font-size: 0.9rem; }
    .spin { width: 14px; height: 14px; border: 2px solid #333; border-top-color: #7eb8f7; border-radius: 50%; animation: spin 0.55s linear infinite; display: inline-block; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .rec-section-hdr { display: flex; align-items: center; justify-content: space-between; margin: 1rem 0 0.5rem; }
    .rec-section-hdr label { margin: 0; }
    .rec-add-btns { display: flex; gap: 0.4rem; }
  </style>
</head>
<body>

<div id="pin-overlay">
  <div class="pin-box">
    <div class="pin-skull">☠</div>
    <div class="pin-title">DeadSwitch Portal</div>
    <div class="pin-sub">Enter your app PIN to continue</div>
    <input type="password" id="pin-input" placeholder="PIN" inputmode="numeric"
           style="text-align:center;font-size:1.1rem;letter-spacing:0.3em;"
           onkeydown="if(event.key==='Enter')tryPin()">
    <button class="btn btn-primary" style="width:100%;margin-top:0.75rem;" onclick="tryPin()">Unlock</button>
    <div id="pin-error">Incorrect PIN — try again.</div>
  </div>
</div>

<div id="app" style="display:none;">
  <nav>
    <span class="brand">☠ DeadSwitch</span>
    <span class="nav-tab active" id="nt-messages" onclick="showTab('messages')">Messages</span>
    <span class="nav-tab" id="nt-settings" onclick="showTab('settings')">Settings</span>
  </nav>

  <div class="container" id="tab-messages">
    <div class="page-header">
      <div class="page-title">Messages</div>
      <button class="btn btn-primary" onclick="openModal()">+ New Message</button>
    </div>
    <div id="messages-list"></div>
  </div>

  <div class="container" id="tab-settings" style="display:none;">
    <div class="page-title" style="margin-bottom:1.25rem;">Settings</div>
    <div class="card">
      <div class="section-label">TEST SMS</div>
      <div class="field"><label>Send test to (phone number)</label><input type="tel" id="test-to" placeholder="+12025551234"></div>
      <button class="btn btn-green" id="test-btn" onclick="testSend()">Send Test Message</button>
      <div id="test-alert"></div>
    </div>
  </div>
</div>

<!-- Message modal -->
<div class="overlay" id="msg-overlay" onclick="if(event.target===this)closeModal()">
  <div class="modal">
    <div class="modal-title" id="modal-title">New Message</div>

    <div class="field" id="group-name-field" style="display:none;">
      <label>Group Name</label>
      <input type="text" id="m-name" placeholder="e.g. Family, Work, Emergency" autocomplete="off">
    </div>

    <div class="field">
      <label>Message to send</label>
      <textarea id="m-message" placeholder="What gets sent when the switch triggers…"></textarea>
    </div>

    <div class="rec-section-hdr">
      <label style="font-size:0.75rem;color:#666;font-weight:600;letter-spacing:0.8px;">RECIPIENTS</label>
      <div class="rec-add-btns">
        <button type="button" class="btn btn-ghost btn-sm" onclick="openContactsPicker()">Contacts</button>
        <button type="button" class="btn btn-ghost btn-sm" id="manual-btn" onclick="toggleAddRec()">Manual</button>
      </div>
    </div>

    <div id="rec-list"></div>
    <div id="no-recs" style="color:#555;font-size:0.84rem;padding:0.35rem 0 0.5rem;">No recipients yet.</div>

    <div class="add-rec-form" id="add-rec-form">
      <div class="add-rec-row">
        <input type="text" id="r-name"  placeholder="Name" autocomplete="off">
        <input type="tel"  id="r-phone" placeholder="Phone" autocomplete="off">
        <button class="btn btn-primary btn-sm" onclick="addRecipient()">Add</button>
        <button class="btn btn-ghost btn-sm"   onclick="toggleAddRec()">✕</button>
      </div>
    </div>

    <div class="modal-actions">
      <button class="btn btn-ghost" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="saveMessage()">Save</button>
    </div>
  </div>
</div>

<!-- Contacts picker -->
<div class="overlay" id="contacts-overlay" onclick="if(event.target===this)closeContactsPicker()">
  <div class="modal">
    <div class="modal-title" style="margin-bottom:0.75rem;">Select Contact</div>
    <input type="text" id="contacts-search" placeholder="Search contacts…" oninput="filterContacts(this.value)">
    <div id="contacts-list"><div class="contacts-loading"><span class="spin"></span></div></div>
    <div class="modal-actions" style="margin-top:0.75rem;">
      <button class="btn btn-ghost" onclick="closeContactsPicker()">Cancel</button>
    </div>
  </div>
</div>

<script>
'use strict';

let _pin = sessionStorage.getItem('ds_pin') || '';
let _messages = [];
let _editId = null;
let _recs = [];
let _phonebook = null;
let _filteredBook = [];

// ── Auth ─────────────────────────────────────────────────────────────────────
async function init() {
  try {
    await api('GET', '/settings');
    unlock();
  } catch(e) {
    if (e.message === '401') showPinScreen();
    else unlock();
  }
}

async function tryPin() {
  _pin = document.getElementById('pin-input').value.trim();
  try {
    await api('GET', '/settings');
    sessionStorage.setItem('ds_pin', _pin);
    document.getElementById('pin-error').style.display = 'none';
    unlock();
  } catch(e) {
    if (e.message === '401') {
      _pin = '';
      document.getElementById('pin-error').style.display = '';
    } else {
      sessionStorage.setItem('ds_pin', _pin);
      unlock();
    }
  }
}

function showPinScreen() {
  document.getElementById('pin-overlay').style.display = 'flex';
  setTimeout(() => document.getElementById('pin-input').focus(), 50);
}

function unlock() {
  document.getElementById('pin-overlay').style.display = 'none';
  document.getElementById('app').style.display = '';
  loadMessages();
}

// ── API ───────────────────────────────────────────────────────────────────────
async function api(method, path, body) {
  const h = {'Content-Type': 'application/json'};
  if (_pin) h['Authorization'] = 'Bearer ' + _pin;
  const res = await fetch('/api' + path, {
    method, headers: h,
    body: body != null ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401) throw new Error('401');
  return res.json();
}

// ── Tabs ──────────────────────────────────────────────────────────────────────
function showTab(t) {
  ['messages','settings'].forEach(x => {
    document.getElementById('tab-' + x).style.display = x === t ? '' : 'none';
    document.getElementById('nt-' + x).classList.toggle('active', x === t);
  });
  if (t === 'messages') loadMessages();
  if (t === 'settings') loadSettings();
}

// ── Messages ──────────────────────────────────────────────────────────────────
async function loadMessages() {
  _messages = await api('GET', '/messages');
  renderMessages();
}

function renderMessages() {
  const el = document.getElementById('messages-list');
  if (_messages.length === 0) {
    el.innerHTML = '<div class="card empty">No messages configured — tap + New Message to add one.</div>';
    return;
  }
  el.innerHTML = _messages.map(m => {
    const recs = m.recipients || [];
    const recText = recs.length === 0
      ? 'No recipients'
      : recs.length + ' recipient' + (recs.length === 1 ? '' : 's') + ': ' + recs.map(r => esc(r.name)).join(', ');
    const enabled = m.enabled !== 0;
    return `
    <div class="card" style="padding:0.9rem 1rem;${enabled ? '' : 'opacity:0.45;'}">
      <div class="item-row">
        <div class="item-info">
          <div class="item-name" style="display:flex;align-items:center;gap:0.4rem;">
            ${esc(m.name)}
            ${!enabled ? '<span style="font-size:0.72rem;color:#888;background:#333;border-radius:4px;padding:1px 6px;">disabled</span>' : ''}
          </div>
          <div class="item-recipients">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            ${esc(recText)}
          </div>
          ${m.message ? `<div class="item-msg">${esc(m.message)}</div>` : ''}
        </div>
        <div class="item-actions">
          <button class="btn btn-ghost btn-sm" onclick="toggleMsg(${m.id},${enabled ? 0 : 1})">${enabled ? 'Disable' : 'Enable'}</button>
          <button class="btn btn-ghost btn-sm" onclick="openModal(${m.id})">Edit</button>
          <button class="btn btn-danger btn-sm" onclick="delMessage(${m.id},'${esc(m.name)}')">Delete</button>
        </div>
      </div>
    </div>`;
  }).join('');
}

function openModal(id) {
  _editId = id ?? null;
  const m = id ? _messages.find(x => x.id === id) : null;
  document.getElementById('modal-title').textContent = id ? 'Edit Message' : 'New Message';
  document.getElementById('m-name').value    = m?.name    ?? '';
  document.getElementById('m-message').value = m?.message ?? '';
  _recs = m ? (m.recipients || []).map(r => ({name: r.name, phone: r.phone})) : [];
  document.getElementById('add-rec-form').classList.remove('open');
  document.getElementById('r-name').value  = '';
  document.getElementById('r-phone').value = '';
  renderRecList();
  document.getElementById('msg-overlay').classList.add('open');
  setTimeout(() => document.getElementById('m-message').focus(), 50);
}

function closeModal() {
  document.getElementById('msg-overlay').classList.remove('open');
}

function renderRecList() {
  const el   = document.getElementById('rec-list');
  const none = document.getElementById('no-recs');
  const gf   = document.getElementById('group-name-field');
  none.style.display = _recs.length === 0 ? '' : 'none';
  gf.style.display   = _recs.length >= 2  ? '' : 'none';
  el.innerHTML = _recs.map((r, i) => `
    <div class="rec-row">
      <div class="rec-info">
        <div class="rec-name">${esc(r.name)}</div>
        <div class="rec-phone">${esc(r.phone)}</div>
      </div>
      <button class="btn-rm" onclick="removeRec(${i})">✕</button>
    </div>`).join('');
}

function removeRec(i) { _recs.splice(i, 1); renderRecList(); }

function toggleAddRec() {
  const f = document.getElementById('add-rec-form');
  f.classList.toggle('open');
  if (f.classList.contains('open')) setTimeout(() => document.getElementById('r-name').focus(), 30);
}

function addRecipient() {
  const name  = document.getElementById('r-name').value.trim();
  const phone = document.getElementById('r-phone').value.trim();
  if (!name || !phone) return;
  if (_recs.some(r => r.phone === phone)) return;
  _recs.push({name, phone});
  renderRecList();
  document.getElementById('r-name').value  = '';
  document.getElementById('r-phone').value = '';
  document.getElementById('r-name').focus();
}

document.getElementById('r-phone').addEventListener('keydown', e => {
  if (e.key === 'Enter') { e.preventDefault(); addRecipient(); }
});

async function saveMessage() {
  let name;
  if (_recs.length >= 2) {
    name = document.getElementById('m-name').value.trim();
    if (!name) { document.getElementById('m-name').focus(); return; }
  } else if (_recs.length === 1) {
    name = _recs[0].name;
  } else {
    return;
  }
  const message = document.getElementById('m-message').value.trim();
  const body = {name, message, recipients: _recs};
  if (_editId) await api('PUT', '/messages/' + _editId, body);
  else         await api('POST', '/messages', body);
  closeModal();
  await loadMessages();
}

async function delMessage(id, name) {
  if (!confirm('Delete "' + name + '"?')) return;
  await api('DELETE', '/messages/' + id);
  await loadMessages();
}

async function toggleMsg(id, enabledVal) {
  await api('PATCH', '/messages/' + id, {enabled: enabledVal});
  await loadMessages();
}

// ── Contacts picker ───────────────────────────────────────────────────────────
async function openContactsPicker() {
  document.getElementById('contacts-search').value = '';
  document.getElementById('contacts-list').innerHTML = '<div class="contacts-loading"><span class="spin"></span></div>';
  document.getElementById('contacts-overlay').classList.add('open');
  setTimeout(() => document.getElementById('contacts-search').focus(), 80);

  if (!_phonebook) {
    try {
      _phonebook = await api('GET', '/phonebook');
    } catch(e) {
      document.getElementById('contacts-list').innerHTML =
        '<div class="contacts-loading" style="color:#c87e7e;">Failed to load contacts.</div>';
      return;
    }
  }
  _filteredBook = _phonebook;
  renderContactsList(_phonebook);
}

function closeContactsPicker() {
  document.getElementById('contacts-overlay').classList.remove('open');
}

function filterContacts(q) {
  if (!_phonebook) return;
  const lq = q.toLowerCase();
  _filteredBook = q ? _phonebook.filter(c =>
    c.name.toLowerCase().includes(lq) ||
    c.phones.some(p => p.includes(lq))
  ) : _phonebook;
  renderContactsList(_filteredBook);
}

function renderContactsList(list) {
  const el = document.getElementById('contacts-list');
  if (list.length === 0) {
    el.innerHTML = '<div class="contacts-loading">No contacts found.</div>';
    return;
  }
  el.innerHTML = list.map((c, ci) => {
    const already = _recs.some(r => c.phones.includes(r.phone));
    if (c.phones.length === 1) {
      return `<div class="contact-item${already ? '" style="opacity:0.4;cursor:default' : ''}" onclick="${already ? '' : `pickContact(${ci},0)`}">
        <div class="contact-item-name">${esc(c.name)}</div>
        <div class="contact-item-phone">${esc(c.phones[0])}</div>
      </div>`;
    }
    return `<div class="contact-item" style="cursor:default;">
      <div class="contact-item-name">${esc(c.name)}</div>
      <div class="contact-phones">${c.phones.map((p, pi) => {
        const used = _recs.some(r => r.phone === p);
        return `<div class="contact-phone-opt${used ? '" style="opacity:0.4;cursor:default' : ''}" onclick="${used ? '' : `pickContact(${ci},${pi})`}">${esc(p)}</div>`;
      }).join('')}</div>
    </div>`;
  }).join('');
}

function pickContact(ci, pi) {
  const c = _filteredBook[ci];
  const phone = c.phones[pi];
  if (_recs.some(r => r.phone === phone)) return;
  _recs.push({name: c.name, phone});
  renderRecList();
  closeContactsPicker();
}

// ── Settings ──────────────────────────────────────────────────────────────────

async function testSend() {
  const to = document.getElementById('test-to').value.trim();
  if (!to) { window.alert('Enter a phone number.'); return; }
  const btn = document.getElementById('test-btn');
  btn.disabled = true;
  btn.innerHTML = '<span class="spin"></span> Sending…';
  try {
    const res = await api('POST', '/settings/test', {to});
    const ok  = res.status === 'success' || (res.data && !res.error);
    showAlert('test-alert', Object.entries(res).map(([k,v]) => k+': '+JSON.stringify(v)).join('\n'), ok);
  } catch(e) {
    showAlert('test-alert', 'Error: ' + e.message, false);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Send Test Message';
  }
}

function showAlert(id, text, ok) {
  let el = document.getElementById(id);
  if (!el) { el = document.createElement('div'); el.id = id; }
  el.className = 'alert ' + (ok ? 'alert-ok' : 'alert-err');
  el.textContent = text;
}

function esc(s) {
  return String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

init();
</script>
</body>
</html>
''';
