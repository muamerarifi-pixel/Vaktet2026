(function () {
  "use strict";

  // ---------- Data ----------
  const BASE = window.VAKTET_BASE; // 365 × 7 minutes, standard time (UTC+1)
  const NAMES = ["Imsaku", "Sabahu", "Lindja e diellit", "Dreka", "Ikindia", "Akshami", "Jacia"];

  // Dallimet sipas Takvimit të BIK. Qytetet pa dallim përdorin kohët bazë.
  const CITIES = [
    { id: "kosove", name: "Kosovë", off: 0 },
    { id: "decan", name: "Deçan", off: 0 },
    { id: "dragash", name: "Dragash (Sharr)", off: 2 },
    { id: "drenas", name: "Drenas", off: 0 },
    { id: "ferizaj", name: "Ferizaj", off: -1 },
    { id: "gjakove", name: "Gjakovë", off: 0 },
    { id: "gjilan", name: "Gjilan", off: -1 },
    { id: "istog", name: "Istog", off: 0 },
    { id: "kline", name: "Klinë", off: 0 },
    { id: "malisheve", name: "Malishevë", off: 0 },
    { id: "mitrovice", name: "Mitrovicë", off: 0 },
    { id: "peje", name: "Pejë", off: 0 },
    { id: "podujeve", name: "Podujevë", off: -1 },
    { id: "prishtine", name: "Prishtinë", off: -1 },
    { id: "prizren", name: "Prizren", off: 0 },
    { id: "rahovec", name: "Rahovec", off: 0 },
    { id: "skenderaj", name: "Skënderaj", off: 0 },
    { id: "suhareke", name: "Suharekë", off: 0 },
    { id: "vushtrri", name: "Vushtrri", off: -1 }
  ];

  const MONTHS = ["janar", "shkurt", "mars", "prill", "maj", "qershor", "korrik", "gusht", "shtator", "tetor", "nëntor", "dhjetor"];
  const WEEKDAYS = ["E diel", "E hënë", "E martë", "E mërkurë", "E enjte", "E premte", "E shtunë"];
  const WEEKDAYS_SHORT = ["Di", "Hë", "Ma", "Më", "En", "Pr", "Sh"];
  const HIJRI_MONTHS = ["Muharrem", "Safer", "Rebiul Evel", "Rebiul Ahir", "Xhumadel Ula", "Xhumadel Ahire", "Rexheb", "Shaban", "Ramazan", "Sheval", "Dhul Kade", "Dhul Hixhe"];
  const TZ = "Europe/Belgrade"; // zona kohore që përdor Kosova
  const DAY_MS = 86400000;

  // ---------- Storage ----------
  const store = {
    get(k, fallback) { try { const v = localStorage.getItem("vaktet:" + k); return v === null ? fallback : v; } catch (e) { return fallback; } },
    set(k, v) { try { localStorage.setItem("vaktet:" + k, v); } catch (e) { /* ignore */ } }
  };

  // ---------- Date helpers ----------
  const utcOf = (day) => Date.UTC(day.y, day.m - 1, day.d);
  const fromUtc = (ms) => { const t = new Date(ms); return { y: t.getUTCFullYear(), m: t.getUTCMonth() + 1, d: t.getUTCDate() }; };
  const addDays = (day, n) => fromUtc(utcOf(day) + n * DAY_MS);
  const sameDay = (a, b) => a.y === b.y && a.m === b.m && a.d === b.d;
  const daysInMonth = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();
  const weekday = (day) => new Date(utcOf(day)).getUTCDay();
  const pad = (n) => String(n).padStart(2, "0");

  let partsFmt = null;
  try {
    partsFmt = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, year: "numeric", month: "numeric", day: "numeric" });
  } catch (e) { partsFmt = null; }

  // Offset of Kosovo time from UTC (minutes) on a given day.
  // Uses the browser's time-zone database (kept up to date by the OS), with the EU rule as a fallback.
  const offsetCache = new Map();
  function tzOffset(day) {
    const key = day.y * 10000 + day.m * 100 + day.d;
    if (offsetCache.has(key)) return offsetCache.get(key);
    let off = null;
    try {
      const f = new Intl.DateTimeFormat("en-US", { timeZone: TZ, timeZoneName: "shortOffset" });
      const name = f.formatToParts(new Date(utcOf(day) + 10 * 3600000)).find((p) => p.type === "timeZoneName").value;
      const m = /GMT([+-])(\d{1,2})(?::(\d{2}))?/.exec(name);
      if (m) off = (m[1] === "-" ? -1 : 1) * (parseInt(m[2], 10) * 60 + parseInt(m[3] || "0", 10));
      else if (name === "GMT") off = 0;
    } catch (e) { off = null; }
    if (off === null) off = euDst(day) ? 120 : 60;
    offsetCache.set(key, off);
    return off;
  }
  function lastSunday(y, m) {
    const last = new Date(Date.UTC(y, m, 0));
    return last.getUTCDate() - last.getUTCDay();
  }
  function euDst(day) {
    const start = Date.UTC(day.y, 2, lastSunday(day.y, 3));
    const end = Date.UTC(day.y, 9, lastSunday(day.y, 10));
    const t = utcOf(day);
    return t >= start && t < end;
  }

  function kosovoToday() {
    const now = new Date();
    if (partsFmt) {
      const p = partsFmt.formatToParts(now);
      const get = (t) => parseInt(p.find((x) => x.type === t).value, 10);
      return { y: get("year"), m: get("month"), d: get("day") };
    }
    return { y: now.getFullYear(), m: now.getMonth() + 1, d: now.getDate() };
  }

  // Index into the base table. The takvim repeats every year by calendar date; 29 Feb uses 28 Feb.
  function baseIndex(day) {
    const d = day.m === 2 && day.d === 29 ? 28 : day.d;
    return Math.round((Date.UTC(2026, day.m - 1, d) - Date.UTC(2026, 0, 1)) / DAY_MS);
  }

  function dayTimes(day, city) {
    const idx = baseIndex(day) * 7;
    const off = tzOffset(day);
    const midnightUtc = utcOf(day);
    const out = [];
    for (let i = 0; i < 7; i++) {
      const std = BASE[idx + i] + city.off; // minutes after midnight, UTC+1
      const local = std + (off - 60);
      out.push({ i, name: NAMES[i], local, instant: midnightUtc + (std - 60) * 60000 });
    }
    return out;
  }

  const fmtTime = (mins) => pad(Math.floor(mins / 60) % 24) + ":" + pad(mins % 60);

  function hijriText(day, adj) {
    try {
      const f = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", { timeZone: "UTC", day: "numeric", month: "numeric", year: "numeric" });
      const p = f.formatToParts(new Date(utcOf(day) + adj * DAY_MS + 12 * 3600000));
      const get = (t) => parseInt(p.find((x) => x.type === t).value, 10);
      const hm = get("month");
      if (!(hm >= 1 && hm <= 12)) return "";
      return get("day") + " " + HIJRI_MONTHS[hm - 1] + " " + get("year") + " h.";
    } catch (e) { return ""; }
  }

  function longDate(day) {
    return WEEKDAYS[weekday(day)] + ", " + day.d + " " + MONTHS[day.m - 1] + " " + day.y;
  }

  // ---------- State ----------
  const $ = (id) => document.getElementById(id);
  const cityById = (id) => CITIES.find((c) => c.id === id) || CITIES[0];
  const state = {
    view: "today",
    city: cityById(store.get("city", "kosove")),
    theme: store.get("theme", "auto"),
    hijriAdj: parseInt(store.get("hijri", "0"), 10) || 0,
    alarmOffset: parseInt(store.get("alarm", "30"), 10) || 30,
    font: ["figtree", "nunito", "lora", "mono"].includes(store.get("font", "figtree")) ? store.get("font", "figtree") : "figtree",
    fontScale: [0.9, 1, 1.12, 1.25].includes(parseFloat(store.get("fontScale", "1"))) ? parseFloat(store.get("fontScale", "1")) : 1,
    tilt: store.get("tilt", "1") === "1",
    countdownWeight: [300, 500, 700, 900].includes(parseInt(store.get("countdownWeight", "900"), 10)) ? parseInt(store.get("countdownWeight", "900"), 10) : 900,
    today: kosovoToday(),
    selected: null,
    cursor: null,
    nextInstant: null,
    skyRows: null
  };
  state.selected = state.today;
  state.cursor = { y: state.today.y, m: state.today.m };

  // ---------- Theme ----------
  function applyTheme() {
    const root = document.documentElement;
    if (state.theme === "light" || state.theme === "dark") root.dataset.theme = state.theme;
    else delete root.dataset.theme;
    updateChrome();
  }

  // Font style, text size and countdown thickness (the settings)
  function applyLook() {
    const r = document.documentElement;
    if (state.font === "figtree") delete r.dataset.font; else r.dataset.font = state.font;
    r.style.setProperty("--text-scale", String(state.fontScale));
    r.style.setProperty("--cd-weight", String(state.countdownWeight));
  }

  // The phone's status bar takes the page colour, or the top of the sky when the card fills the screen.
  const SKY_TOP = { night: "#060A1C", dawn: "#121844", morning: "#154F96", noon: "#0B3F7E", afternoon: "#1A3560", dusk: "#0F1032" };
  let lastChrome = "";
  function mixHex(hex, rgb, a, shade) {
    const n = parseInt(hex.slice(1), 16);
    const c = [n >> 16, (n >> 8) & 255, n & 255].map((v, i) => Math.round((v * (1 - a) + rgb[i] * a) * shade));
    return "#" + c.map((v) => v.toString(16).padStart(2, "0")).join("").toUpperCase();
  }
  const phone = window.matchMedia("(max-width: 899px)");
  function isFullSky() {
    const b = document.body;
    return b.classList.contains("is-focus") && b.classList.contains("no-tips") && b.dataset.view === "today" &&
      !$("nextCard").hidden && phone.matches;
  }
  function updateChrome() {
    wakeSky();
    const dark = state.theme === "dark" || (state.theme === "auto" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    let c = dark ? "#000000" : "#EEF1EE";
    const top = SKY_TOP[document.body.dataset.phase];
    if (top && isFullSky()) {
      // matches the sky's top edge after the screen's top shade (and the night dimming in dark mode)
      const forbid = $("nextCard").classList.contains("is-forbidden");
      c = mixHex(top, [120, 18, 22], forbid ? 0.72 : 0, (dark ? 0.86 : 1) * 0.7);
    }
    if (c === lastChrome) return;
    lastChrome = c;
    document.querySelectorAll('meta[name="theme-color"]').forEach((m) => m.setAttribute("content", c));
  }

  // On a phone, today is the sky itself: the times, the alarm and the tips are swiped up over it.
  function applyFocus() {
    const on = phone.matches;
    document.body.classList.toggle("is-focus", on);
    document.body.classList.toggle("no-tips", on);
    updateChrome();
  }

  // Daily tips. Two per day, never the same day to day:
  // even days get one life tip + one tip as a Muslim, odd days two life tips.
  // Each list is gone through in a shuffled order before any tip comes back.
  function shuffled(n, seed) {
    let a = seed >>> 0;
    const rnd = () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
    const idx = Array.from({ length: n }, (_, i) => i);
    for (let i = n - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); const t = idx[i]; idx[i] = idx[j]; idx[j] = t; }
    return idx;
  }
  function tipAt(list, k, salt) {
    const n = list.length;
    const cycle = Math.floor(k / n);
    return list[shuffled(n, cycle * 7919 + salt + 1000000)[((k % n) + n) % n]];
  }
  function tipsFor(day) {
    const T = window.VAKTET_TIPS;
    if (!T || !T.h || !T.m) return [];
    const d = Math.round(utcOf(day) / DAY_MS) - 20727; // 1 Oct 2026 = day 0
    const pair = Math.floor(d / 2);
    if (((d % 2) + 2) % 2 === 0) return [{ tag: "Për jetën", text: tipAt(T.h, pair * 3, 11) }, { tag: "Si musliman", text: tipAt(T.m, pair, 29) }];
    return [{ tag: "Për jetën", text: tipAt(T.h, pair * 3 + 1, 11) }, { tag: "Për jetën", text: tipAt(T.h, pair * 3 + 2, 11) }];
  }
  function renderTips() {
    const key = state.selected.y + "-" + state.selected.m + "-" + state.selected.d;
    ["tipsList", "skyTips"].forEach((id) => {
      const box = $(id);
      if (box.dataset.day === key) return;
      box.dataset.day = key;
      box.innerHTML = "";
      tipsFor(state.selected).forEach((t) => {
        const a = document.createElement("article"); a.className = "tip" + (t.tag === "Si musliman" ? " is-muslim" : "");
        const g = document.createElement("span"); g.className = "tip-tag"; g.textContent = t.tag;
        const p = document.createElement("p"); p.textContent = t.text;
        a.append(g, p);
        box.appendChild(a);
      });
    });
  }

  // Keep the installed app in portrait (the manifest does this on Android; this is a fallback).
  function lockPortrait() {
    try {
      const standalone = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone;
      if (standalone && screen.orientation && screen.orientation.lock) screen.orientation.lock("portrait").catch(() => {});
    } catch (e) { /* ignore */ }
  }

  // ---------- Rendering ----------
  function renderCities() {
    const sel = $("city");
    sel.innerHTML = "";
    CITIES.forEach((c) => {
      const o = document.createElement("option");
      o.value = c.id;
      o.textContent = c.name;
      sel.appendChild(o);
    });
    sel.value = state.city.id;
  }

  function cityNote() {
    const c = state.city;
    if (c.off === 0) return c.id === "kosove" ? "Kohët bazë të Takvimit të Bashkësisë Islame të Kosovës." : c.name + ": kohët bazë të Takvimit të BIK.";
    const n = Math.abs(c.off);
    return c.name + ": " + n + " minut" + (n === 1 ? "ë" : "a") + " " + (c.off < 0 ? "më herët" : "më vonë") + " se kohët bazë të Takvimit.";
  }

  // The moment shown: now, or — while another day is shown — the same time of day on that day, so its sky,
  // sun, moon and season can be seen as they will be (or were) at this hour.
  function viewNow() {
    const sel = state.selected, today = state.today;
    return Date.now() + (utcOf(sel) - utcOf(today)) + (tzOffset(today) - tzOffset(sel)) * 60000;
  }

  function renderToday() {
    const day = state.selected;
    const isToday = sameDay(day, state.today);
    $("dateText").textContent = longDate(day);
    $("hijriText").textContent = hijriText(day, state.hijriAdj) || String.fromCharCode(160);
    $("backToday").hidden = isToday;
    $("nextCard").hidden = false;
    $("cityNote").textContent = cityNote();
    $("skySheetTitle").textContent = isToday ? "Vaktet e sotme" : "Vaktet e ditës";
    $("skyTipsTitle").textContent = $("tipsTitle").textContent = isToday ? "Dy këshilla për sot" : "Dy këshilla për këtë ditë";

    const rows = dayRows(day, state.city);
    const now = viewNow();
    const next = rows.find((r) => r.prayer && r.instant > now) || null;

    // the list, and the same rows in the sheet that is swiped up over the full-screen sky
    const list = $("times"), sheetList = $("skyTimes");
    const items = [], sheetItems = [];
    rows.forEach((r) => {
      const li = document.createElement("li");
      if (r.instant <= now) li.classList.add("is-past");
      if (r === next) { li.classList.add("is-next"); li.setAttribute("aria-current", "time"); }
      const n = document.createElement("span"); n.className = "t-name"; n.textContent = r.name;
      const v = document.createElement("span"); v.className = "t-time"; v.textContent = fmtTime(r.local);
      li.append(n, v);
      items.push(li);
      sheetItems.push(li.cloneNode(true));
    });
    list.replaceChildren(...items);
    sheetList.replaceChildren(...sheetItems);
    $("skySheetCity").textContent = state.city.name;

    $("alarmCard").hidden = true;
    $("skyAlarm").hidden = true;
    $("tips").hidden = false;
    applyFocus();
    renderTips();
    renderNextCard(day, rows, next, now);
    renderAlarm(day, rows, now);
    renderDayline(rows);
    tick();
  }

  // A quiet sign that a prayer time has come: a soft ring of light spreads across the sky.
  function pulse() {
    if (reduceMotion.matches || document.hidden || !sameDay(state.selected, state.today)) return;
    const el = $("skyPulse");
    el.classList.remove("is-on");
    void el.offsetWidth; // restart the animation
    el.classList.add("is-on");
  }

  // Prohibited times: 15 min after sunrise, 10 min before dhuhr begins, 15 min before sunset (Akshami).
  function forbiddenWindows(rows) {
    const sun = rowOf(rows, "sunrise"), dh = rowOf(rows, "dhuhr"), mg = rowOf(rows, "maghrib");
    const w = (name, startRow, fromMin, toMin) => ({
      name,
      start: startRow.instant + fromMin * 60000,
      end: startRow.instant + toMin * 60000,
      label: fmtTime(startRow.local + fromMin) + " – " + fmtTime(startRow.local + toMin)
    });
    return [
      w("Lindja e diellit", sun, 0, 15),
      w("Zeniti", dh, -10, 0),
      w("Perëndimi i diellit", mg, -15, 0)
    ];
  }

  // ---------- Sky (the card's background follows the current prayer time) ----------
  // night = Jacia, dawn = Sabahu, morning = after sunrise, noon = Dreka, afternoon = Ikindia, dusk = Akshami
  function skyPhase(rows, now) {
    const at = (k) => rowOf(rows, k).instant;
    if (now < at("imsak")) return "night";
    if (now < at("sunrise")) return "dawn";
    if (now < at("dhuhr")) return "morning";
    if (now < at("asr")) return "noon";
    if (now < at("maghrib")) return "afternoon";
    if (now < at("isha")) return "dusk";
    return "night";
  }

  function updateSky(rows, now) {
    state.skyRows = rows;
    const phase = skyPhase(rows, now);
    if (document.body.dataset.phase !== phase) document.body.dataset.phase = phase;
    updateOrb(now);
  }

  // The sun travels from sunrise to sunset along an arc; the moon from sunset to the next sunrise.
  // The sun rises from behind the hills on the left and sets behind them on the right; the moon keeps its own hours.
  function updateOrb(now) {
    const rows = state.skyRows;
    if (!rows) return;
    const card = $("nextCard"), g = skyGeometry();
    state.scene = skyScene(rows, now);
    applySkyColours(rows, now);
    const p = state.scene.sunProgress;
    let orb = "none";
    if (p >= -.06 && p <= 1.06) {
      const a = arcAt(p, g), vis = aboveHills(a.y, g, 14);
      if (vis > 0) {
        orb = "sun";
        card.style.setProperty("--ox", a.x.toFixed(4));
        card.style.setProperty("--oy", a.y.toFixed(4));
        card.style.setProperty("--oyz", a.y.toFixed(4));
        card.querySelector(".sky-orb").style.opacity = vis.toFixed(3);
      }
    }
    if (orb === "none") card.querySelector(".sky-orb").style.opacity = "0";
    if (card.dataset.orb !== orb) card.dataset.orb = orb;
    updateMoon(rows, now);
  }

  // ---------- The real Moon, and a scene for every hour ----------
  // The Moon's phase from its mean orbit with the main corrections (Meeus, Astronomical Algorithms, ch. 48).
  function moonPhase(ms) {
    const T = (ms / DAY_MS + 2440587.5 - 2451545) / 36525;
    const rad = (d) => d * Math.PI / 180;
    const mod = (x) => ((x % 360) + 360) % 360;
    const D = mod(297.8501921 + 445267.1114034 * T), M = mod(357.5291092 + 35999.0502909 * T), Mp = mod(134.9633964 + 477198.8675055 * T);
    const i = 180 - D - 6.289 * Math.sin(rad(Mp)) + 2.1 * Math.sin(rad(M)) - 1.274 * Math.sin(rad(2 * D - Mp)) -
      .658 * Math.sin(rad(2 * D)) - .214 * Math.sin(rad(2 * Mp)) - .11 * Math.sin(rad(D));
    return { illumination: (1 + Math.cos(rad(i))) / 2, waxing: D < 180, elongation: D };
  }
  // The Moon crosses the sky in about 12 h, reaching its highest point one lunar day per orbit after the Sun:
  // with the Sun at new moon, rising at sunset at full moon, rising around midnight at last quarter.
  function moonAt(rows, now) {
    const ph = moonPhase(now);
    const noon = rowOf(rows, "dhuhr").instant - 5 * 60000;
    const lunarDay = 24 * 3600000 + 50 * 60000, halfArc = 6.2 * 3600000;
    let transit = noon + ph.elongation / 360 * lunarDay;
    while (transit - now > lunarDay / 2) transit -= lunarDay;
    while (now - transit > lunarDay / 2) transit += lunarDay;
    const p = (now - (transit - halfArc)) / (2 * halfArc);
    const pc = Math.min(1, Math.max(0, p)), s = Math.sin(Math.PI * pc);
    return { up: p > 0 && p < 1, p, x: .12 + .76 * pc, y: .34 - .24 * s, yFull: .3 - .12 * s, k: ph.illumination, waxing: ph.waxing };
  }
  // The lit part of the Moon in a 40 × 40 box: the bright edge a half circle, the shadow's edge a half ellipse.
  function moonPath(k, waxing) {
    const side = waxing ? 1 : -1, bulge = 1 - 2 * k, r = 14, c = 20, pts = [];
    for (let i = 0; i <= 24; i++) { const a = -Math.PI / 2 + Math.PI * i / 24; pts.push([c + side * r * Math.cos(a), c + r * Math.sin(a)]); }
    for (let i = 24; i >= 0; i--) { const a = -Math.PI / 2 + Math.PI * i / 24; pts.push([c + side * r * Math.cos(a) * bulge, c + r * Math.sin(a)]); }
    return "M" + pts.map((q) => q[0].toFixed(2) + " " + q[1].toFixed(2)).join("L") + "Z";
  }
  let lastMoon = "";
  // Where the hills meet the sky, and a point on the arc the sun and the moon travel (fractions of the card):
  // p 0 = rising, 1 = setting; outside that range they are behind the hills. The arc climbs quickly out of the
  // hills and then stays high, and low in the sky it keeps near the edges, clear of the countdown.
  function skyGeometry() {
    const card = $("nextCard"), h = card.clientHeight || window.innerHeight, full = isFullSky();
    const hh = full ? Math.min(.2 * h, 170) : Math.min(.26 * h, 64);
    return { h, full, horizon: 1 - hh * .45 / h, peak: full ? .2 : .1 };
  }
  function arcAt(p, g) {
    const sn = Math.sin(Math.PI * p), rise = sn <= 0 ? sn : Math.pow(sn, .45);
    return { x: .5 - .42 * Math.cos(Math.PI * p), y: g.horizon - (g.horizon - g.peak) * rise };
  }
  // how much of a disc of radius r px at height y shows above the hills (1 above, 0 once behind them)
  const aboveHills = (y, g, r) => Math.min(1, Math.max(0, 1 - ((y - g.horizon) * g.h + r) / (3 * r)));

  // The Moon where it really is, in its real phase: it rises from behind the hills on the left and sets behind
  // them on the right; by day a pale ghost; on new-moon nights only its faint outline, low in the west.
  function updateMoon(rows, now) {
    const m = moonAt(rows, now), el = $("skyMoon"), card = $("nextCard"), g = skyGeometry();
    const sunP = state.scene ? state.scene.sunProgress : .5;
    const night = sunP < 0 || sunP > 1, isNew = m.k < .015;
    state.moon = m;
    let x, y, vis;
    if (isNew) {
      vis = night ? 1 : 0;
      x = .86; y = g.horizon - (g.full ? 46 : 20) / g.h;
    } else if (m.p >= -.06 && m.p <= 1.06) {
      const a = arcAt(m.p, g);
      x = a.x; y = a.y; vis = aboveHills(y, g, g.full ? 24 : 14);
    } else vis = 0;
    el.hidden = vis <= 0;
    if (el.hidden) return;
    el.style.opacity = vis.toFixed(3);
    el.classList.toggle("is-new", isNew);
    card.style.setProperty("--mx", x.toFixed(4));
    card.style.setProperty("--my", y.toFixed(4));
    card.style.setProperty("--myz", y.toFixed(4));
    card.style.setProperty("--moon-glow", (.55 + .45 * m.k).toFixed(3));
    card.style.setProperty("--earthshine", (.1 * (1 - m.k)).toFixed(3));
    el.classList.toggle("is-day", !night);
    const key = Math.round(m.k * 200) + (m.waxing ? "w" : "n");
    if (key !== lastMoon) {
      lastMoon = key;
      $("moonLit").setAttribute("d", moonPath(m.k, m.waxing));
      $("moonLit").parentNode.setAttribute("transform", "rotate(" + (m.waxing ? -12 : 12) + " 20 20)");
    }
  }

  // ---------- The colours of the sky, melting from one prayer time into the next ----------
  const PALETTES = {
    night: { colors: ["#060A1C", "#11173A", "#232A5E"], stops: [0, .48, 1], glow: "#3A3F96", hazeA: [118, 92, 214, .42], hazeB: [36, 80, 176, .42], sun: [255, 236, 196], stars: 1, hill: [2, 4, 16, .62] },
    dawn: { colors: ["#121844", "#3E3A82", "#B5687E", "#EC9C78"], stops: [0, .42, .8, 1], glow: "#B4698C", hazeA: [255, 152, 140, .5], hazeB: [116, 88, 206, .42], sun: [255, 196, 156], stars: .5, hill: [28, 14, 44, .55] },
    morning: { colors: ["#154F96", "#2E78C0", "#D7A77E"], stops: [0, .52, 1], glow: "#3F86CC", hazeA: [255, 214, 160, .5], hazeB: [120, 190, 255, .45], sun: [255, 242, 206], stars: 0, hill: [10, 36, 74, .45] },
    noon: { colors: ["#0B3F7E", "#1C64AC", "#4E95D2"], stops: [0, .52, 1], glow: "#2A78C4", hazeA: [176, 222, 255, .42], hazeB: [36, 112, 204, .5], sun: [255, 251, 230], stars: 0, hill: [6, 30, 66, .48] },
    afternoon: { colors: ["#1A3560", "#7E4F5C", "#D0864B"], stops: [0, .54, 1], glow: "#CC8048", hazeA: [255, 186, 104, .5], hazeB: [150, 84, 128, .42], sun: [255, 206, 128], stars: 0, hill: [40, 18, 18, .5] },
    dusk: { colors: ["#0F1032", "#432152", "#A6434F", "#DC7452"], stops: [0, .48, .84, 1], glow: "#A8456A", hazeA: [255, 118, 104, .45], hazeB: [108, 58, 172, .45], sun: [255, 206, 128], stars: .65, hill: [16, 6, 22, .6] }
  };
  const hexRgb = (h) => { const n = parseInt(h.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; };
  const mixArr = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
  function sampleGradient(pal, x) {
    const c = pal.colors.map(hexRgb), st = pal.stops;
    if (x <= st[0]) return c[0];
    for (let i = 0; i < st.length - 1; i++) if (x <= st[i + 1]) return mixArr(c[i], c[i + 1], (x - st[i]) / (st[i + 1] - st[i]));
    return c[c.length - 1];
  }
  // each prayer time's sky melts into the next over up to 45 minutes either side of the change
  function skyBlend(rows, now) {
    const at = (k) => rowOf(rows, k).instant;
    const marks = [at("isha") - DAY_MS, at("imsak"), at("sunrise"), at("dhuhr"), at("asr"), at("maghrib"), at("isha"), at("imsak") + DAY_MS];
    const phases = ["night", "dawn", "morning", "noon", "afternoon", "dusk", "night"];
    let i = 0;
    while (i < phases.length - 1 && now >= marks[i + 1]) i++;
    const width = (k) => Math.min(45 * 60000, .45 * (marks[k + 1] - marks[k]));
    if (i > 0 && phases[i - 1] !== phases[i]) {
      const w = Math.min(width(i - 1), width(i)), d = now - marks[i];
      if (d < w) return { from: phases[i - 1], to: phases[i], t: smooth01(.5 + d / (2 * w)) };
    }
    if (i < phases.length - 1 && phases[i + 1] !== phases[i]) {
      const w = Math.min(width(i), width(i + 1)), d = marks[i + 1] - now;
      if (d < w) return { from: phases[i], to: phases[i + 1], t: smooth01(.5 - d / (2 * w)) };
    }
    return { from: phases[i], to: phases[i], t: 0 };
  }
  function blendPalette(b) {
    const A = PALETTES[b.from], B = PALETTES[b.to], t = b.from === b.to ? 0 : b.t;
    const stops = [0, .2, .4, .6, .8, 1];
    return {
      colors: stops.map((x) => mixArr(sampleGradient(A, x), sampleGradient(B, x), t)), stops,
      glow: mixArr(hexRgb(A.glow), hexRgb(B.glow), t), hazeA: mixArr(A.hazeA, B.hazeA, t), hazeB: mixArr(A.hazeB, B.hazeB, t),
      sun: mixArr(A.sun, B.sun, t), stars: A.stars + (B.stars - A.stars) * t, hill: mixArr(A.hill, B.hill, t)
    };
  }

  // ---------- Seasons on the hills ----------
  // (day of the year, colour): snowy winter, green spring, golden summer, orange-brown autumn
  const SEASONS = [[15, [93, 110, 128]], [105, [63, 143, 82]], [196, [201, 162, 74]], [288, [176, 96, 44]]];
  const dayOfYear = (day) => Math.round((utcOf(day) - Date.UTC(day.y, 0, 1)) / DAY_MS) + 1;
  function seasonColor(day) {
    const d0 = dayOfYear(day), d = d0 < SEASONS[0][0] ? d0 + 365 : d0;
    for (let i = 0; i < SEASONS.length; i++) {
      const [a, ca] = SEASONS[i], [b0, cb] = SEASONS[(i + 1) % SEASONS.length], b = i + 1 < SEASONS.length ? b0 : b0 + 365;
      if (d >= a && d < b) return mixArr(ca, cb, smooth01((d - a) / (b - a)));
    }
    return SEASONS[0][1];
  }
  function snowOn(day) {
    let d = dayOfYear(day) - 15;
    if (d > 182) d -= 365;
    if (d < -182) d += 365;
    return smooth01((60 - Math.abs(d)) / 25);
  }

  // Sets the blended sky, the season's hills and the snow as CSS variables (only when they change).
  let lastSkyKey = "";
  function applySkyColours(rows, now) {
    const b = skyBlend(rows, now), pal = blendPalette(b);
    state.pal = pal;
    const day = state.selected, daylight = 1 - pal.stars * .85, snow = snowOn(day);
    let hill = mixArr(pal.hill.slice(0, 3), seasonColor(day), .12 + .5 * daylight);
    hill = mixArr(hill, [220, 228, 236], .25 * snow * daylight);
    const rgb = (c) => "rgb(" + c.map(Math.round).join(",") + ")";
    const rgba = (c) => "rgba(" + c.slice(0, 3).map(Math.round).join(",") + "," + c[3].toFixed(3) + ")";
    const vars = {
      "--sky": "linear-gradient(180deg, " + pal.colors.map((c, i) => rgb(c) + " " + Math.round(pal.stops[i] * 100) + "%").join(", ") + ")",
      "--glow": rgb(pal.glow), "--haze-a": rgba(pal.hazeA), "--haze-b": rgba(pal.hazeB),
      "--sun": pal.sun.map(Math.round).join(", "), "--stars": pal.stars.toFixed(3),
      "--hill": "rgba(" + hill.map(Math.round).join(",") + "," + pal.hill[3].toFixed(3) + ")",
      "--snow": (snow * (.3 + .5 * daylight)).toFixed(3)
    };
    const key = JSON.stringify(vars);
    if (key === lastSkyKey) return;
    lastSkyKey = key;
    const st = document.body.style;
    Object.entries(vars).forEach(([k, v]) => st.setProperty(k, v));
  }

  // Temporal hours: sunrise is hour 6, sunset 18, the middle of the night 0, so every scene keeps to the sun
  // in every season and every year.
  function temporalHour(rows, now) {
    const rise = rowOf(rows, "sunrise").instant, set = rowOf(rows, "maghrib").instant;
    if (now >= rise && now < set) return 6 + 12 * (now - rise) / (set - rise);
    const from = now >= set ? set : set - DAY_MS, to = now >= set ? rise + DAY_MS : rise;
    const h = 18 + 12 * (now - from) / (to - from);
    return h >= 24 ? h - 24 : h;
  }
  const smooth01 = (x) => { const t = Math.min(1, Math.max(0, x)); return t * t * (3 - 2 * t); };
  function windowAt(h, a, b, c, d) {
    if (a > d) { const u = (x) => (x < a ? x + 24 : x); h = u(h); b = u(b); c = u(c); d += 24; }
    if (h <= a || h >= d) return 0;
    if (h < b) return smooth01((h - a) / (b - a));
    if (h <= c) return 1;
    return smooth01((d - h) / (d - c));
  }
  // the colour each hour lays over the sky: [r, g, b, strength], index = temporal hour
  const HOUR_TINTS = [
    [21, 26, 82, .16], [18, 24, 72, .17], [20, 27, 76, .15], [29, 35, 88, .12], [58, 47, 110, .10], [138, 79, 134, .10],
    [255, 148, 102, .12], [255, 192, 138, .10], [255, 226, 181, .06], [200, 230, 255, .06], [181, 220, 255, .06], [230, 244, 255, .06],
    [255, 255, 255, .07], [255, 244, 214, .06], [255, 230, 176, .07], [255, 212, 140, .09], [255, 184, 106, .11], [255, 142, 87, .13],
    [229, 92, 120, .13], [138, 77, 158, .13], [74, 62, 142, .13], [46, 47, 122, .14], [35, 39, 105, .15], [27, 32, 94, .16]
  ];
  // clouds through the day: [temporal hour, cover, thin, sunset colours]
  const CLOUD_KEYS = [[4.6, 0, 1, 1], [5.6, .3, 1, 1], [6.6, .35, 1, .7], [8, .35, .9, 0], [11, .55, .4, 0], [13, .85, 0, 0],
    [16, .9, 0, 0], [17.2, .75, .2, .8], [18.3, .5, .5, 1], [19.2, 0, 1, 1]];
  function cloudsAt(h) {
    if (h <= CLOUD_KEYS[0][0] || h >= CLOUD_KEYS[CLOUD_KEYS.length - 1][0]) return [0, 1, 1];
    for (let i = 0; i < CLOUD_KEYS.length - 1; i++) {
      const A = CLOUD_KEYS[i], B = CLOUD_KEYS[i + 1];
      if (h >= A[0] && h < B[0]) { const f = smooth01((h - A[0]) / (B[0] - A[0])); return [1, 2, 3].map((j) => A[j] + (B[j] - A[j]) * f); }
    }
    return [0, 1, 1];
  }

  function skyScene(rows, now) {
    const h = temporalHour(rows, now), i = Math.floor(h) % 24, f = h - Math.floor(h);
    const A = HOUR_TINTS[i], B = HOUR_TINTS[(i + 1) % 24];
    const tint = [0, 1, 2, 3].map((j) => A[j] + (B[j] - A[j]) * f);
    let lights = 0;
    if (h >= 18) lights = smooth01((h - 18.4) / 1.2);
    else if (h < 6.6) {
      const late = 1 - .8 * smooth01(h / 3.2), early = .45 * windowAt(h, 3.6, 4.6, 5.6, 6.6);
      lights = Math.max(late * (h < 5.5 ? 1 : smooth01((6.6 - h) / 1.1)), early);
    }
    const summer = state.selected.m >= 6 && state.selected.m <= 8;
    const rise = rowOf(rows, "sunrise").instant, set = rowOf(rows, "maghrib").instant;
    const [cover, thin, sunset] = cloudsAt(h);
    return {
      hour: h, tint, sunProgress: (now - rise) / (set - rise),
      cloudCover: cover, cloudThin: thin, cloudSunset: sunset,
      milkyWay: windowAt(h, 20.2, 22.5, 3.2, 4.6),
      lights: Math.round(lights * 40) / 40,
      brightStar: Math.max(windowAt(h, 4.4, 5, 5.6, 6.1), windowAt(h, 18.1, 18.6, 19.2, 19.9)),
      mist: windowAt(h, 5.6, 6.3, 7.2, 8.6),
      birds: Math.max(windowAt(h, 6.3, 6.8, 8.2, 9), windowAt(h, 16.4, 16.9, 17.6, 18.2)),
      plane: windowAt(h, 9, 9.6, 15.4, 16),
      nightPlane: windowAt(h, 19, 19.6, 23, 23.6),
      fireflies: summer ? windowAt(h, 18.6, 19.2, 21.6, 22.4) : 0,
      starBoost: windowAt(h, 19.5, 22.5, 2.5, 5.2)
    };
  }

  function renderNextCard(day, rows, next, now) {
    const card = $("nextCard");
    updateSky(rows, now);
    let intro = "Namazi i ardhshëm";
    if (!next) { next = dayRows(addDays(day, 1), state.city).find((r) => r.prayer); intro = "Nesër"; }

    const windows = forbiddenWindows(rows);
    const active = windows.find((w) => now >= w.start && now < w.end) || null;
    const bounds = [next.instant];
    windows.forEach((w) => { if (w.start > now) bounds.push(w.start); if (w.end > now) bounds.push(w.end); });
    state.changeAt = Math.min.apply(null, bounds);

    state.altInstant = null;
    $("nextAlt").hidden = true;

    if (active) {
      card.classList.add("is-forbidden");
      $("nextIntro").textContent = "Kohë e ndaluar për namaz";
      $("nextName").textContent = active.name;
      $("nextTime").textContent = active.label;
      $("countdownLabel").textContent = "deri sa të kalojë";
      state.nextInstant = active.end;
      if (next.instant !== active.end) setAlt("Namazi i ardhshëm: " + next.name + " " + fmtTime(next.local), next.instant);
      return;
    }

    card.classList.remove("is-forbidden");
    $("nextIntro").textContent = intro;
    $("nextName").textContent = next.name;
    $("nextTime").textContent = fmtTime(next.local);
    $("countdownLabel").textContent = "deri në fillim";
    state.nextInstant = next.instant;

    // After midnight, while waiting for Imsaku, also show when Sabahu can be prayed.
    if (next.key === "imsak" && intro !== "Nesër") {
      const sabah = rowOf(rows, "sabah");
      setAlt("Sabahu mund të falet në " + fmtTime(sabah.local) + ", pas", sabah.instant);
    }
  }

  // Suggested alarm for Sabahu: a set number of minutes before sunrise (default 30).
  // Shown after Jacia has passed (for tomorrow) and after midnight until the alarm time (for today).
  function renderAlarm(day, rows, now) {
    const off = state.alarmOffset;
    const alarmOf = (r) => {
      const sun = rowOf(r, "sunrise"), sabah = rowOf(r, "sabah");
      let local = sun.local - off, instant = sun.instant - off * 60000;
      if (instant < sabah.instant) { local = sabah.local; instant = sabah.instant; }
      return { local, instant, sunrise: sun.local };
    };
    const todayAlarm = alarmOf(rows);
    let alarm = null, when = "";
    const isha = rowOf(rows, "isha");
    if (now >= isha.instant) {
      alarm = alarmOf(dayRows(addDays(day, 1), state.city));
      when = "Nesër";
    } else if (now < todayAlarm.instant) {
      alarm = todayAlarm;
      when = "Sot";
    }
    // Re-render when the suggestion should appear or disappear.
    [isha.instant, todayAlarm.instant].forEach((t) => { if (t > now && t < state.changeAt) state.changeAt = t; });
    if (!alarm) return;
    $("alarmTime").textContent = fmtTime(alarm.local);
    $("alarmSub").textContent = when + ", " + off + " min para lindjes së diellit (" + fmtTime(alarm.sunrise) + ")";
    $("alarmCard").hidden = false;
    $("skyAlarmTime").textContent = $("alarmTime").textContent;
    $("skyAlarmSub").textContent = $("alarmSub").textContent;
    $("skyAlarm").hidden = false;
  }

  function setAlt(text, instant) {
    $("nextAltText").textContent = text;
    state.altInstant = instant;
    $("nextAlt").hidden = false;
  }

  // Rows for one day, in time order (the countdown targets).
  // Obligatory times follow the BIK takvim, with Dreka/Xhumaja on the full hour as on takvimi.net.
  const rowsCache = new Map();
  function dayRows(day, city) {
    const cacheKey = day.y + "-" + day.m + "-" + day.d + ":" + city.id;
    if (rowsCache.has(cacheKey)) return rowsCache.get(cacheKey);
    const t = dayTimes(day, city);
    const fri = weekday(day) === 5;
    const dh = t[3];
    const drekaLocal = dh.local % 60 === 0 ? dh.local : (Math.floor(dh.local / 60) + 1) * 60;
    const row = (name, key, local, instant) => ({ name, key, local, instant, prayer: true });
    const rows = [
      row("Imsaku", "imsak", t[0].local, t[0].instant),
      row("Sabahu", "sabah", t[1].local, t[1].instant),
      row("Lindja e diellit", "sunrise", t[2].local, t[2].instant),
      row(fri ? "Hyrja e xhumasë" : "Hyrja e drekës", "dhuhr", dh.local, dh.instant),
      row(fri ? "Xhumaja" : "Dreka", "dreka", drekaLocal, dh.instant + (drekaLocal - dh.local) * 60000),
      row("Ikindia", "asr", t[4].local, t[4].instant),
      row("Akshami", "maghrib", t[5].local, t[5].instant),
      row("Jacia", "isha", t[6].local, t[6].instant)
    ];
    if (rowsCache.size > 200) rowsCache.clear();
    rowsCache.set(cacheKey, rows);
    return rows;
  }

  const rowOf = (rows, key) => rows.find((r) => r.key === key);

  // Minutes after local midnight of `day` for an instant (handles the night of a clock change).
  function localMinutes(instant, day) {
    try {
      const f = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
      const p = f.formatToParts(new Date(instant));
      const h = parseInt(p.find((x) => x.type === "hour").value, 10);
      const m = parseInt(p.find((x) => x.type === "minute").value, 10);
      return h * 60 + m;
    } catch (e) {
      return Math.round((instant - (utcOf(day) - tzOffset(day) * 60000)) / 60000);
    }
  }

  function renderDayline(times) {
    const ticks = $("daylineTicks");
    ticks.innerHTML = "";
    const now = viewNow();
    times.forEach((t) => {
      const s = document.createElement("span");
      s.style.left = (t.local / 1440 * 100).toFixed(2) + "%";
      if (t.instant <= now) s.classList.add("done");
      ticks.appendChild(s);
    });
    positionNow();
  }

  function positionNow() {
    const day = state.selected, now = viewNow();
    const midnight = utcOf(day) - tzOffset(day) * 60000;
    const frac = Math.min(1, Math.max(0, (now - midnight) / DAY_MS));
    const pct = (frac * 100).toFixed(2) + "%";
    $("daylineFill").style.width = pct;
    $("daylineNow").style.left = pct;
    updateOrb(now);
  }

  function renderMonth() {
    const { y, m } = state.cursor;
    $("monthTitle").textContent = MONTHS[m - 1].charAt(0).toUpperCase() + MONTHS[m - 1].slice(1) + " " + y;
    const body = $("monthBody");
    body.innerHTML = "";
    const frag = document.createDocumentFragment();
    for (let d = 1; d <= daysInMonth(y, m); d++) {
      const day = { y, m, d };
      const tr = document.createElement("tr");
      if (sameDay(day, state.today)) tr.classList.add("is-today");
      if (sameDay(day, state.selected)) tr.classList.add("is-selected");
      if (weekday(day) === 5) tr.classList.add("is-friday");
      const td0 = document.createElement("td");
      td0.className = "c-day";
      td0.innerHTML = d + "<small>" + WEEKDAYS_SHORT[weekday(day)] + "</small>";
      tr.appendChild(td0);
      dayTimes(day, state.city).forEach((t) => {
        const td = document.createElement("td");
        td.textContent = fmtTime(t.local);
        tr.appendChild(td);
      });
      tr.addEventListener("click", () => {
        state.selected = day;
        if (!window.matchMedia("(min-width: 900px)").matches) setView("today");
        renderAll();
      });
      frag.appendChild(tr);
    }
    body.appendChild(frag);
  }

  function renderAll() {
    renderToday();
    renderMonth();
  }

  function setView(v) {
    state.view = v;
    document.body.dataset.view = v;
    $("tabToday").setAttribute("aria-pressed", String(v === "today"));
    $("tabMonth").setAttribute("aria-pressed", String(v === "month"));
    window.scrollTo(0, 0);
    updateChrome();
  }

  function select(day) {
    state.selected = day;
    state.cursor = { y: day.y, m: day.m };
    renderAll();
  }

  // ---------- Clock ----------
  function tick() {
    updateChrome();
    const t = kosovoToday();
    if (!sameDay(t, state.today)) {
      const wasToday = sameDay(state.selected, state.today);
      state.today = t;
      if (wasToday) { state.selected = t; state.cursor = { y: t.y, m: t.m }; }
      renderAll();
      return;
    }
    if (state.nextInstant === null) return;
    const now = viewNow();
    if ((state.changeAt && now >= state.changeAt) || state.nextInstant - now <= 0) {
      if (state.nextInstant - now <= 0 && now - state.nextInstant < 5000) pulse();
      renderToday();
      return;
    }
    setCount(state.nextInstant - now);
    if (state.altInstant) $("nextAltCount").textContent = fmtCount(state.altInstant - now);
    positionNow();
  }

  function fmtCount(ms) {
    const s = Math.max(0, Math.floor(ms / 1000));
    return pad(Math.floor(s / 3600)) + ":" + pad(Math.floor(s / 60) % 60) + ":" + pad(s % 60);
  }

  // The big countdown: digits at full strength, the colons a touch softer.
  let lastCount = "";
  function setCount(ms) {
    const text = fmtCount(ms);
    if (text === lastCount) return;
    lastCount = text;
    $("countdown").innerHTML = text.split(":").map((p) => '<span class="cd-n">' + p + "</span>").join('<span class="cd-sep">:</span>');
  }

  // ---------- Smooth changes ----------
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  // Hiding the times, the full-screen sky, the tabs and another day cross-fade (where the browser can).
  function smoothly(change) {
    if (!document.startViewTransition || reduceMotion.matches || document.hidden) { change(); return; }
    document.startViewTransition(change);
  }

  // ---------- The prayer-times sheet of the full-screen sky ----------
  // Swipe up (or tap the hint) to show the day's times; swipe down, tap the sky, Escape or Back to hide them.
  const sheet = { v: 0, drag: null, history: false };

  function setReveal(v) {
    sheet.v = Math.min(1, Math.max(0, v));
    const b = document.body;
    b.style.setProperty("--reveal", sheet.v.toFixed(4));
    b.classList.toggle("sheet-visible", sheet.v > 0);
    b.classList.toggle("sheet-open", sheet.v >= 0.5);
    $("swipeHint").setAttribute("aria-expanded", String(sheet.v >= 0.5));
  }

  let settleTimer = 0;
  function settleSheet(open) {
    const b = document.body;
    if (!reduceMotion.matches) {
      b.classList.add("sheet-settling");
      clearTimeout(settleTimer);
      settleTimer = setTimeout(() => {
        b.classList.remove("sheet-settling");
        if (!open) b.classList.remove("sheet-visible");
      }, 440);
    }
    setReveal(open ? 1 : 0);
    if (!open && !reduceMotion.matches) b.classList.add("sheet-visible"); // keep it painted while it slides away
    // Back closes the sheet instead of leaving the app
    if (open && !sheet.history) { history.pushState({ vaktetSheet: true }, ""); sheet.history = true; }
    if (!open && sheet.history) { sheet.history = false; if (history.state && history.state.vaktetSheet) history.back(); }
  }

  function sheetHeight() { return $("skySheet").offsetHeight + 90 || 420; }

  function bindSheet() {
    $("swipeHint").addEventListener("click", () => settleSheet(true));
    window.addEventListener("popstate", () => {
      if (sheet.history) { sheet.history = false; if (sheet.v > 0) settleSheet(false); }
    });
    document.addEventListener("keydown", (e) => { if (e.key === "Escape" && sheet.v > 0) settleSheet(false); });

    document.addEventListener("pointerdown", (e) => {
      if (!isFullSky() || e.button > 0) return;
      if (e.target.closest && e.target.closest(".top, .tabs, dialog")) return;
      // a swipe from the bottom edge is the phone's home gesture, not a request for the times
      if (sheet.v === 0 && e.clientY > window.innerHeight - 56) return;
      // a sheet taller than the screen scrolls under the finger instead (tap the sky or Back to close it)
      const sh = $("skySheet");
      if (sheet.v > 0 && e.target.closest && e.target.closest(".sky-sheet") && sh.scrollHeight > sh.clientHeight + 2) return;
      sheet.drag = { id: e.pointerId, x0: e.clientX, y0: e.clientY, v0: sheet.v, last: e.clientY, t: e.timeStamp, t0: e.timeStamp, vy: 0, moving: false, side: false, target: e.target };
    });
    document.addEventListener("pointermove", (e) => {
      const d = sheet.drag;
      if (!d || e.pointerId !== d.id) return;
      const dy = e.clientY - d.y0, dx = e.clientX - d.x0;
      if (d.side) return;
      if (!d.moving) {
        // a sideways swipe changes the day (only while the times are hidden)
        if (sheet.v === 0 && Math.abs(dx) > 12 && Math.abs(dx) > Math.abs(dy) * 1.3) { d.side = true; return; }
        if (Math.abs(dy) < 8) return;
        d.moving = true;
        document.body.classList.remove("sheet-settling");
        document.body.classList.add("sheet-visible");
      }
      const dt = Math.max(1, e.timeStamp - d.t);
      d.vy = 0.8 * ((e.clientY - d.last) / dt) + 0.2 * d.vy; // px per ms, smoothed
      d.last = e.clientY; d.t = e.timeStamp;
      setReveal(d.v0 - dy / sheetHeight());
    });
    const end = (e) => {
      const d = sheet.drag;
      if (!d || e.pointerId !== d.id) return;
      sheet.drag = null;
      if (d.side) {
        // swipe left for the next day, right for the day before: its sky, moon, sun and season at this hour
        const dx = e.clientX - d.x0, fast = Math.abs(dx) / Math.max(1, e.timeStamp - d.t0) > .25;
        if (Math.abs(dx) > 60 || (fast && Math.abs(dx) > 30)) smoothly(() => select(addDays(state.selected, dx < 0 ? 1 : -1)));
        const swallow = (ev) => { ev.stopPropagation(); ev.preventDefault(); };
        window.addEventListener("click", swallow, { capture: true, once: true });
        setTimeout(() => window.removeEventListener("click", swallow, { capture: true }), 0);
        return;
      }
      if (d.moving) {
        const open = Math.abs(d.vy) > 0.3 ? d.vy < 0 : sheet.v > 0.4;
        settleSheet(open);
        // a drag is not a tap
        const swallow = (ev) => { ev.stopPropagation(); ev.preventDefault(); };
        window.addEventListener("click", swallow, { capture: true, once: true });
        setTimeout(() => window.removeEventListener("click", swallow, { capture: true }), 0);
      } else if (sheet.v > 0 && !(d.target.closest && d.target.closest(".sky-sheet, button, select, a"))) {
        settleSheet(false); // a tap on the sky closes it
      }
    };
    document.addEventListener("pointerup", end);
    document.addEventListener("pointercancel", end);
  }

  // Leaving the full-screen sky closes the sheet, so it starts closed next time.
  function resetSheetIfHidden() {
    if (sheet.v > 0 && !isFullSky()) {
      setReveal(0);
      document.body.classList.remove("sheet-visible", "sheet-settling");
      if (sheet.history) { sheet.history = false; if (history.state && history.state.vaktetSheet) history.back(); }
    }
  }

  // ---------- The living sky (full screen) ----------
  // Stars that twinkle on their own beats, now and then a shooting star, soft turning sun rays, drifting clouds.
  const PAL = {
    night: { stars: 1, sun: [255, 236, 196], tint: null, clouds: 0 },
    dawn: { stars: .5, sun: [255, 196, 156], tint: [255, 170, 160], clouds: .12 },
    morning: { stars: 0, sun: [255, 242, 206], tint: [255, 255, 255], clouds: .28 },
    noon: { stars: 0, sun: [255, 251, 230], tint: [255, 255, 255], clouds: .28 },
    afternoon: { stars: 0, sun: [255, 206, 128], tint: [255, 232, 196], clouds: .22 },
    dusk: { stars: .65, sun: [255, 206, 128], tint: [255, 150, 140], clouds: .12 }
  };
  function seeded(seed) {
    let a = seed >>> 0;
    return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  // mostly tiny and faint, a handful a little brighter, some faintly blue or warm, each twinkling on its own beat;
  // the last 90 come out only deep in the night
  const BASE_STARS = 170;
  const FIELD = (() => {
    const r = seeded(1447);
    const tints = [[255, 255, 255], [255, 255, 255], [220, 230, 255], [255, 241, 222]];
    return Array.from({ length: BASE_STARS + 90 }, (_, i) => {
      const y = Math.pow(r(), 1.35), lucky = i < BASE_STARS && r() < .07;
      return {
        x: r(), y,
        r: lucky ? .8 + r() * .35 : .35 + r() * .4,
        bright: lucky ? .8 + r() * .2 : .22 + Math.pow(r(), 2) * .5,
        tint: tints[Math.floor(r() * tints.length)],
        period: 1.4 + r() * 3.6, phase: r() * Math.PI * 2, depth: .4 + r() * .5
      };
    });
  })();
  // the dust of the Milky Way: along the band, across it, size, brightness
  const DUST = (() => {
    const r = seeded(786);
    return Array.from({ length: 260 }, () => [r(), (r() + r() + r() - 1.5) / 1.5, .25 + r() * .35, .25 + r() * .55]);
  })();
  const FIREFLIES = (() => {
    const r = seeded(613);
    return Array.from({ length: 16 }, () => [r(), .74 + r() * .2, .5 + r(), r() * Math.PI * 2]);
  })();
  // windows of the villages on the hills, in the hills' own 400 × 60 space
  const WINDOWS = (() => {
    const out = [];
    try {
      const ctx = document.createElement("canvas").getContext("2d");
      const near = new Path2D("M0 46c36-7 66-2 104-9 40-7 70 6 112 5 40-1 64-12 102-12 34 0 58 8 82 6V60H0Z");
      const far = new Path2D("M0 34C30 27 58 30 92 22c30-7 52 2 84 6 34 4 58-17 96-19 30-2 48 12 76 13 22 1 36-6 52-8V60H0Z");
      const r = seeded(1912);
      [[70, 8], [150, 7], [232, 10], [290, 9], [356, 7]].forEach(([vx, count]) => {
        let made = 0, tries = 0;
        while (made < count && tries++ < 200) {
          const x = vx + (r() - .5) * 40, y = 14 + r() * 28;
          const inNear = ctx.isPointInPath(near, x, y), inFar = ctx.isPointInPath(far, x, y);
          const onNear = inNear && !ctx.isPointInPath(near, x, y - 5);
          const onFar = !inNear && inFar && !ctx.isPointInPath(far, x, y - 6);
          if (!onNear && !onFar) continue;
          out.push([x, y, r(), r()]);
          made++;
        }
      });
    } catch (e) { /* no canvas: no windows */ }
    return out;
  })();
  const CLOUDS = [[.14, 1, 150, .1], [.3, .75, 115, .62], [.44, .55, 95, .35], [.22, .85, 170, .85], [.38, .65, 130, .22]];
  const PUFFS = [[-.55, .1, .34], [-.22, -.08, .46], [.16, -.16, .52], [.5, .02, .4], [.02, .14, .44]];
  const wave = (t, period, phase) => .5 + .5 * Math.sin(t / period * Math.PI * 2 + (phase || 0));
  const rgba = (c, a) => "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a.toFixed(3) + ")";

  // The sky moves slowly, so about 30 pictures a second look just as smooth, for a fraction of the work.
  const live = { raf: 0, t0: performance.now(), w: 0, h: 0, dpr: 1, last: 0, frontKey: "" };
  function sizeCanvas(cv, w, h, dpr) {
    const W = Math.round(w * dpr), H = Math.round(h * dpr);
    if (cv.width !== W || cv.height !== H) { cv.width = W; cv.height = H; }
    const ctx = cv.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return ctx;
  }
  function drawSky(now) {
    live.raf = 0;
    if (!isFullSky() || document.hidden || reduceMotion.matches) { document.body.classList.remove("sky-is-live"); return; }
    if (now - live.last < 31) { live.raf = requestAnimationFrame(drawSky); return; }
    live.last = now;
    document.body.classList.add("sky-is-live");
    const cv = $("skyLive");
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = cv.clientWidth, h = cv.clientHeight;
    live.w = w; live.h = h; live.dpr = dpr;
    const ctx = sizeCanvas(cv, w, h, dpr);
    ctx.clearRect(0, 0, w, h);
    const t = (now - live.t0) / 1000;
    const pal = { stars: state.pal ? state.pal.stars : (PAL[document.body.dataset.phase] || PAL.night).stars, sun: state.pal ? state.pal.sun.map(Math.round) : [255, 236, 196] };
    const sc = state.scene || { tint: [0, 0, 0, 0], starBoost: 0, milkyWay: 0, brightStar: 0, birds: 0, plane: 0, nightPlane: 0, fireflies: 0, lights: 0, mist: 0, hour: 12 };
    const moon = state.moon && state.moon.up ? state.moon : null;
    const day = $("nextCard").dataset.orb === "sun";
    const g0 = skyGeometry(), horizonY = g0.horizon * h;

    // a warm glow along the hills while the sun rises or sets, a pale one where the moon is about to rise
    const glow = (x, strength, c, width, height) => {
      if (strength <= .01) return;
      ctx.save(); ctx.translate(x * w, horizonY); ctx.scale(1, (h * height) / (w * width));
      const gr = ctx.createRadialGradient(0, 0, 0, 0, 0, w * width);
      gr.addColorStop(0, rgba(c, strength)); gr.addColorStop(.4, rgba(c, strength * .35)); gr.addColorStop(1, rgba(c, 0));
      ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(0, 0, w * width, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    };
    const sp = sc.sunProgress === undefined ? .5 : sc.sunProgress;
    const edge = Math.min(Math.abs(sp), Math.abs(sp - 1));
    if (edge < .12) glow(.5 - .42 * Math.cos(Math.PI * Math.min(1.05, Math.max(-.05, sp))), .42 * (1 - edge / .12), [255, 154, 92], .75, .2);
    const mm = state.moon;
    if (mm && mm.k >= .015 && mm.p > -.2 && mm.p < -.02 && (sp < -.04 || sp > 1.04)) {
      glow(.08, .22 * smooth01((mm.p + .2) / .14) * (.4 + .6 * mm.k), [230, 236, 255], .45, .14);
    }

    // the colour of the hour
    if (sc.tint[3] > 0) {
      const g = ctx.createLinearGradient(0, 0, 0, h), c = sc.tint.slice(0, 3).map(Math.round), k = sc.tint[3];
      g.addColorStop(0, rgba(c, k * .55)); g.addColorStop(.6, rgba(c, k)); g.addColorStop(1, rgba(c, k * .7));
      ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    }

    // the Milky Way, deep in the night
    const mw = sc.milkyWay * pal.stars * (moon ? 1 - .6 * moon.k : 1);
    if (mw > .02) {
      const fx = -.1 * w, fy = .52 * h, tx = 1.1 * w, ty = .02 * h;
      const len = Math.hypot(tx - fx, ty - fy), ux = (tx - fx) / len, uy = (ty - fy) / len, half = Math.min(w, h) * .16;
      ctx.save(); ctx.translate(fx, fy); ctx.rotate(Math.atan2(uy, ux));
      const g = ctx.createLinearGradient(0, -half, 0, half);
      g.addColorStop(0, "rgba(200,210,255,0)"); g.addColorStop(.3, rgba([200, 210, 255], .07 * mw));
      g.addColorStop(.5, rgba([235, 228, 255], .1 * mw)); g.addColorStop(.7, rgba([200, 210, 255], .07 * mw)); g.addColorStop(1, "rgba(200,210,255,0)");
      ctx.fillStyle = g; ctx.fillRect(0, -half, len, 2 * half);
      ctx.restore();
      DUST.forEach(([along, across, r, b]) => {
        const x = fx + ux * along * len - uy * across * half * .9, y = fy + uy * along * len + ux * across * half * .9;
        if (y > h * .62) return;
        ctx.fillStyle = rgba([234, 239, 255], b * .5 * mw);
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
      });
    }

    // clouds that change with the hour: thin wisps in the morning, fuller in the afternoon, lit pink and gold
    // at sunrise and sunset, none at night
    const cover = sc.cloudCover || 0;
    if (cover > .01) {
      const thin = sc.cloudThin, sunset = sc.cloudSunset, strength = .3 * (.55 + .45 * cover);
      const tint = mixArr([255, 255, 255], [255, 176, 154], sunset).map(Math.round), rim = mixArr([255, 255, 255], [255, 208, 138], sunset).map(Math.round);
      const shown = cover * CLOUDS.length;
      CLOUDS.forEach(([cy, scale0, crossing, offset], i) => {
        const fade = Math.min(1, Math.max(0, shown - i));
        if (fade <= 0) return;
        const scale = scale0 * (.75 + .45 * cover), cw = w * .55 * scale, span = w + 2 * cw;
        const cx = ((offset + t / crossing) % 1) * span - cw, y = cy * h * .7;
        const a = strength * (.75 + .25 * scale0) * fade;
        ctx.save(); ctx.translate(cx, y); ctx.scale(1 + .3 * thin, 1 - .55 * thin); ctx.translate(-cx, -y);
        PUFFS.forEach(([dx, dy, r]) => {
          const x = cx + dx * cw, yy = y + dy * cw, rad = r * cw;
          if (sunset > .05) {
            const ry = yy + rad * .18, gr = ctx.createRadialGradient(x, ry, 0, x, ry, rad);
            gr.addColorStop(0, rgba(rim, a * .8 * sunset)); gr.addColorStop(1, rgba(rim, 0));
            ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(x, ry, rad, 0, Math.PI * 2); ctx.fill();
          }
          const g = ctx.createRadialGradient(x, yy, 0, x, yy, rad);
          g.addColorStop(0, rgba(tint, a)); g.addColorStop(.45, rgba(tint, a * .55)); g.addColorStop(1, rgba(tint, 0));
          ctx.fillStyle = g;
          ctx.beginPath(); ctx.arc(x, yy, rad, 0, Math.PI * 2); ctx.fill();
        });
        ctx.restore();
      });
    }

    // stars: a sharper twinkle, a tiny glint on the bright ones, and more of them deep in the night
    if (pal.stars > 0) {
      const boxH = h * .66, boost = sc.starBoost, wash = moon ? 1 - .35 * moon.k : 1;
      const count = BASE_STARS + Math.round((FIELD.length - BASE_STARS) * boost);
      ctx.lineWidth = .6; ctx.lineCap = "round";
      for (let i = 0; i < count; i++) {
        const s = FIELD[i];
        const fade = s.y <= .55 ? 1 : 1 - (s.y - .55) / .45;
        const wv = wave(t, s.period, s.phase);
        const extra = i >= BASE_STARS ? boost : 1;
        const a = Math.min(1, pal.stars * s.bright * (1 - s.depth * wv * wv) * fade * extra * (s.bright > .7 ? 1 : wash) * (1 + .2 * boost));
        if (a <= .02) continue;
        const x = s.x * w, y = s.y * boxH;
        if (s.r > .7) {
          ctx.fillStyle = rgba(s.tint, a * .12);
          ctx.beginPath(); ctx.arc(x, y, s.r * 3.4, 0, Math.PI * 2); ctx.fill();
          const flash = Math.pow(1 - wv, 6);
          if (flash > .05) {
            const l = s.r * (2.5 + 4 * flash);
            ctx.strokeStyle = rgba(s.tint, a * .55 * flash);
            ctx.beginPath(); ctx.moveTo(x - l, y); ctx.lineTo(x + l, y); ctx.moveTo(x, y - l); ctx.lineTo(x, y + l); ctx.stroke();
          }
        }
        ctx.fillStyle = rgba(s.tint, a);
        ctx.beginPath(); ctx.arc(x, y, s.r, 0, Math.PI * 2); ctx.fill();
      }
      // now and then a star falls (more often deep in the night)
      const every = boost > .5 ? 7 : 11, lasts = .9, n = Math.floor(t / every), local = t - n * every;
      const r = seeded(n * 7919 + 13);
      if (pal.stars >= .5 && local <= lasts && r() >= .5) {
        const sx = (.25 + r() * .7) * w, sy = (.04 + r() * .28) * h;
        const ang = (150 + r() * 25) * Math.PI / 180, dx = Math.cos(ang), dy = Math.sin(ang);
        const travel = w * (.35 + r() * .2);
        const p = 1 - Math.pow(1 - local / lasts, 3);
        const hx = sx + dx * travel * p, hy = sy + dy * travel * p;
        const tl = 40 + 45 * Math.sin(Math.PI * p);
        const alpha = Math.sin(Math.PI * local / lasts) * pal.stars * .55;
        const g = ctx.createLinearGradient(hx - dx * tl, hy - dy * tl, hx, hy);
        g.addColorStop(0, "rgba(255,255,255,0)"); g.addColorStop(1, rgba([255, 255, 255], alpha));
        ctx.strokeStyle = g; ctx.lineWidth = .9; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(hx - dx * tl, hy - dy * tl); ctx.lineTo(hx, hy); ctx.stroke();
      }
    }

    // the morning star in the east before sunrise, the evening star in the west after sunset
    if (sc.brightStar > .02) {
      const bx = (sc.hour < 12 ? .1 : .9) * w, by = h * .7, pulse = .85 + .15 * wave(t, 2.6), k = sc.brightStar;
      ctx.fillStyle = rgba([255, 248, 236], .1 * k * pulse); ctx.beginPath(); ctx.arc(bx, by, 9, 0, Math.PI * 2); ctx.fill();
      const l = 6 + 3 * pulse;
      ctx.strokeStyle = rgba([255, 248, 236], .5 * k * pulse); ctx.lineWidth = .8;
      ctx.beginPath(); ctx.moveTo(bx - l, by); ctx.lineTo(bx + l, by); ctx.moveTo(bx, by - l); ctx.lineTo(bx, by + l); ctx.stroke();
      ctx.fillStyle = rgba([255, 248, 236], k); ctx.beginPath(); ctx.arc(bx, by, 1.8, 0, Math.PI * 2); ctx.fill();
    }

    // a small flock: out in the morning, home in the evening
    if (sc.birds > .02) {
      const every = 46, crossing = 30, n = Math.floor(t / every), local = t - n * every;
      if (local <= crossing) {
        const r = seeded(n * 4513 + 7), morning = sc.hour < 12, p = local / crossing;
        const x = (morning ? -.15 + 1.3 * p : 1.15 - 1.3 * p) * w;
        const y = (.2 + r() * .25) * h + Math.sin(p * Math.PI * 2) * 6;
        ctx.strokeStyle = rgba(day ? [30, 36, 56] : [14, 15, 30], .55 * sc.birds); ctx.lineWidth = 1.3; ctx.lineCap = "round";
        const count = 4 + Math.floor(r() * 4), back = morning ? -1 : 1;
        for (let i = 0; i < count; i++) {
          const row = Math.floor((i + 1) / 2), side = i % 2 ? -1 : 1;
          const cx = x + back * row * 14, cy = y + side * row * 9 + r() * 3;
          const span = 5 + r() * 1.5, lift = 2.5 * Math.sin(t * 9 + i * 1.3);
          ctx.beginPath();
          ctx.moveTo(cx - span, cy - lift);
          ctx.quadraticCurveTo(cx - span * .4, cy - lift * .3 - 1.2, cx, cy);
          ctx.quadraticCurveTo(cx + span * .4, cy - lift * .3 - 1.2, cx + span, cy - lift);
          ctx.stroke();
        }
      }
    }

    // a plane high in the day sky, leaving a thin trail
    if (sc.plane > .02) {
      const every = 80, crossing = 55, n = Math.floor(t / every), local = t - n * every, r = seeded(n * 2861 + 3);
      if (local <= crossing + 12 && r() >= .35) {
        const ltr = r() < .5, y0 = (.08 + r() * .22) * h, y1 = y0 + (r() - .5) * .12 * h;
        const at = (q) => [(ltr ? -.05 + 1.1 * q : 1.05 - 1.1 * q) * w, y0 + (y1 - y0) * q];
        const p = Math.min(1, local / crossing), hd = at(p), tl = at(Math.max(0, p - .35));
        const fade = local > crossing ? 1 - (local - crossing) / 12 : 1;
        const g = ctx.createLinearGradient(tl[0], tl[1], hd[0], hd[1]);
        g.addColorStop(0, "rgba(255,255,255,0)"); g.addColorStop(1, rgba([255, 255, 255], .35 * sc.plane * fade));
        ctx.strokeStyle = g; ctx.lineWidth = 1.6; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(tl[0], tl[1]); ctx.lineTo(hd[0], hd[1]); ctx.stroke();
        if (local <= crossing) { ctx.fillStyle = rgba([255, 255, 255], .8 * sc.plane); ctx.beginPath(); ctx.arc(hd[0], hd[1], 1.3, 0, Math.PI * 2); ctx.fill(); }
      }
    }

    // a plane's lights blinking across the evening sky
    if (sc.nightPlane > .02) {
      const every = 95, crossing = 70, n = Math.floor(t / every), local = t - n * every, r = seeded(n * 1733 + 11);
      if (local <= crossing && r() >= .4) {
        const ltr = r() < .5, p = local / crossing, y = (.1 + r() * .25) * h + p * 20;
        const x = (ltr ? -.05 + 1.1 * p : 1.05 - 1.1 * p) * w, k = sc.nightPlane, blink = (t * 1.1) % 1;
        ctx.fillStyle = rgba([255, 255, 255], .55 * k); ctx.beginPath(); ctx.arc(x, y, .9, 0, Math.PI * 2); ctx.fill();
        const col = blink < .12 ? [255, 100, 100] : blink > .5 && blink < .58 ? [255, 255, 255] : null;
        if (col) {
          ctx.fillStyle = rgba(col, .25 * k); ctx.beginPath(); ctx.arc(x, y, 3.2, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = rgba(col, .95 * k); ctx.beginPath(); ctx.arc(x, y, 1.3, 0, Math.PI * 2); ctx.fill();
        }
      }
    }

    // fireflies on summer evenings
    if (sc.fireflies > .02) {
      FIREFLIES.forEach(([fx, fy, sp, ph]) => {
        const x = (fx + .04 * Math.sin(t * .3 * sp + ph)) * w, y = fy * h + 12 * Math.sin(t * .45 * sp + ph * 2);
        const on = Math.pow(Math.max(0, Math.sin(t * 1.3 * sp + ph)), 3) * sc.fireflies;
        if (on < .03) return;
        ctx.fillStyle = rgba([232, 255, 138], .18 * on); ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = rgba([232, 255, 138], .9 * on); ctx.beginPath(); ctx.arc(x, y, 1.4, 0, Math.PI * 2); ctx.fill();
      });
    }

    drawFront(sc, w, h, dpr);

    // a few faint sun rays, turning slowly (they rise with the sun when the sheet opens)
    const card = $("nextCard");
    if (card.dataset.orb === "sun") {
      const cx = parseFloat(card.style.getPropertyValue("--ox")) * w;
      const cy = (parseFloat(card.style.getPropertyValue("--oyz")) * h) - sheet.v * .2 * window.innerHeight;
      if (isFinite(cx) && isFinite(cy)) {
        const reach = Math.min(w, h) * .95;
        const strength = document.body.dataset.phase === "noon" ? .06 : .08;
        const beams = (count, turn, width, alpha) => {
          ctx.beginPath();
          for (let i = 0; i < count; i++) {
            const a = turn + i * Math.PI * 2 / count, half = width * (i % 2 ? .55 : 1);
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + reach * Math.cos(a - half), cy + reach * Math.sin(a - half));
            ctx.lineTo(cx + reach * Math.cos(a + half), cy + reach * Math.sin(a + half));
            ctx.closePath();
          }
          const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, reach);
          g.addColorStop(0, rgba(pal.sun, alpha)); g.addColorStop(.25, rgba(pal.sun, alpha * .3)); g.addColorStop(.8, rgba(pal.sun, 0));
          ctx.fillStyle = g; ctx.fill();
        };
        ctx.globalCompositeOperation = "screen";
        beams(8, t * .02, .07, strength * (.7 + .3 * wave(t, 10)));
        beams(6, -t * .013 + .5, .05, strength * .6 * (.7 + .3 * wave(t, 13, 1.3)));
        ctx.globalCompositeOperation = "source-over";
      }
    }
    live.raf = requestAnimationFrame(drawSky);
  }
  // In front of the hills: valley mist after sunrise, and the lit windows of the villages (on at dusk,
  // going out one by one after midnight, a few again for the Sabah prayer). Redrawn only when they change.
  function drawFront(sc, w, h, dpr) {
    const key = [w, h, dpr, sc.lights, Math.round(sc.mist * 40)].join(",");
    if (key === live.frontKey) return;
    live.frontKey = key;
    const ctx = sizeCanvas($("skyFront"), w, h, dpr);
    ctx.clearRect(0, 0, w, h);
    const hh = Math.min(.2 * h, 170), top = h - hh, sx = w / 400, sy = hh / 60;
    if (sc.mist > .02) {
      [[.2, 30, .32, 1], [.62, 26, .4, .8], [.95, 32, .28, .9]].forEach(([cx, cy, rx, a]) => {
        const x = cx * w, y = top + cy * sy, R = rx * w;
        ctx.save(); ctx.translate(x, y); ctx.scale(1, (11 * sy) / R);
        const g = ctx.createRadialGradient(0, 0, 0, 0, 0, R);
        g.addColorStop(0, rgba([244, 241, 248], .34 * a * sc.mist)); g.addColorStop(1, "rgba(244,241,248,0)");
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, R, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      });
    }
    if (sc.lights > .02) {
      WINDOWS.forEach(([x, y, warmth, order]) => {
        if (order > sc.lights) return;
        const c = [255, Math.round(210 + 32 * warmth), Math.round(122 + 88 * warmth)];
        ctx.fillStyle = rgba(c, .16); ctx.beginPath(); ctx.arc(x * sx, top + y * sy, 3.2, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = rgba(c, .9); ctx.beginPath(); ctx.arc(x * sx, top + y * sy, .95, 0, Math.PI * 2); ctx.fill();
      });
    }
  }
  // ---------- Tilt: the sky gets depth when the phone is tilted ----------
  // Keeps only the change of the phone's angle: tilting moves the sky a little, holding still lets it drift back.
  const tilt = { on: false, base: null, x: 0, y: 0, asked: false };
  function onMotion(e) {
    const a = e.accelerationIncludingGravity;
    if (!a || a.x === null) return;
    const raw = [a.x, a.y];
    tilt.base = tilt.base ? [tilt.base[0] + (raw[0] - tilt.base[0]) * .02, tilt.base[1] + (raw[1] - tilt.base[1]) * .02] : raw;
    const clamp = (v) => Math.max(-10, Math.min(10, v));
    const tx = clamp(-(raw[0] - tilt.base[0]) * 2.2), ty = clamp((raw[1] - tilt.base[1]) * 2.2);
    tilt.x += (tx - tilt.x) * .18; tilt.y += (ty - tilt.y) * .18;
    const card = $("nextCard");
    card.style.setProperty("--tx", tilt.x.toFixed(2));
    card.style.setProperty("--ty", tilt.y.toFixed(2));
  }
  function syncTilt() {
    const want = state.tilt && isFullSky() && !document.hidden && !reduceMotion.matches && "DeviceMotionEvent" in window;
    if (want === tilt.on) return;
    tilt.on = want;
    if (want) window.addEventListener("devicemotion", onMotion);
    else {
      window.removeEventListener("devicemotion", onMotion);
      tilt.base = null; tilt.x = tilt.y = 0;
      $("nextCard").style.setProperty("--tx", "0"); $("nextCard").style.setProperty("--ty", "0");
    }
  }
  // iPhone asks for permission once, on a tap
  function askTiltPermission() {
    if (tilt.asked || !state.tilt || typeof DeviceMotionEvent === "undefined" || typeof DeviceMotionEvent.requestPermission !== "function") return;
    tilt.asked = true;
    DeviceMotionEvent.requestPermission().catch(() => {});
  }

  function wakeSky() {
    syncTilt();
    resetSheetIfHidden();
    if (!live.raf && isFullSky() && !document.hidden && !reduceMotion.matches) live.raf = requestAnimationFrame(drawSky);
  }

  // ---------- Events ----------
  function bind() {
    $("city").addEventListener("change", (e) => {
      state.city = cityById(e.target.value);
      store.set("city", state.city.id);
      renderAll();
    });
    $("prevDay").addEventListener("click", () => select(addDays(state.selected, -1)));
    $("nextDay").addEventListener("click", () => select(addDays(state.selected, 1)));
    $("backToday").addEventListener("click", () => select(state.today));
    $("prevMonth").addEventListener("click", () => {
      const c = state.cursor; state.cursor = c.m === 1 ? { y: c.y - 1, m: 12 } : { y: c.y, m: c.m - 1 }; renderMonth();
    });
    $("nextMonth").addEventListener("click", () => {
      const c = state.cursor; state.cursor = c.m === 12 ? { y: c.y + 1, m: 1 } : { y: c.y, m: c.m + 1 }; renderMonth();
    });
    $("tabToday").addEventListener("click", () => { if (state.view !== "today") smoothly(() => setView("today")); });
    $("tabMonth").addEventListener("click", () => { if (state.view !== "month") smoothly(() => setView("month")); });

    const dlg = $("settings");
    $("settingsBtn").addEventListener("click", () => {
      document.querySelectorAll('input[name="theme"]').forEach((r) => { r.checked = r.value === state.theme; });
      document.querySelectorAll('input[name="hijri"]').forEach((r) => { r.checked = parseInt(r.value, 10) === state.hijriAdj; });
      document.querySelectorAll('input[name="alarm"]').forEach((r) => { r.checked = parseInt(r.value, 10) === state.alarmOffset; });
      document.querySelectorAll('input[name="font"]').forEach((r) => { r.checked = r.value === state.font; });
      document.querySelectorAll('input[name="fontScale"]').forEach((r) => { r.checked = parseFloat(r.value) === state.fontScale; });
      document.querySelectorAll('input[name="countdownWeight"]').forEach((r) => { r.checked = parseInt(r.value, 10) === state.countdownWeight; });
      document.querySelectorAll('input[name="tilt"]').forEach((r) => { r.checked = (r.value === "1") === state.tilt; });
      if (typeof dlg.showModal === "function") dlg.showModal(); else dlg.setAttribute("open", "");
    });
    dlg.addEventListener("click", (e) => { if (e.target === dlg) dlg.close(); });
    document.querySelectorAll('input[name="theme"]').forEach((r) => r.addEventListener("change", () => {
      state.theme = r.value; store.set("theme", r.value); applyTheme();
    }));
    document.querySelectorAll('input[name="hijri"]').forEach((r) => r.addEventListener("change", () => {
      state.hijriAdj = parseInt(r.value, 10); store.set("hijri", r.value); renderToday();
    }));
    document.querySelectorAll('input[name="alarm"]').forEach((r) => r.addEventListener("change", () => {
      state.alarmOffset = parseInt(r.value, 10); store.set("alarm", r.value); renderToday();
    }));
    document.querySelectorAll('input[name="font"]').forEach((r) => r.addEventListener("change", () => {
      state.font = r.value; store.set("font", r.value); applyLook();
    }));
    document.querySelectorAll('input[name="fontScale"]').forEach((r) => r.addEventListener("change", () => {
      state.fontScale = parseFloat(r.value); store.set("fontScale", r.value); applyLook();
    }));
    document.querySelectorAll('input[name="countdownWeight"]').forEach((r) => r.addEventListener("change", () => {
      state.countdownWeight = parseInt(r.value, 10); store.set("countdownWeight", r.value); applyLook();
    }));
    document.querySelectorAll('input[name="tilt"]').forEach((r) => r.addEventListener("change", () => {
      state.tilt = r.value === "1"; store.set("tilt", r.value);
      if (state.tilt) { tilt.asked = false; askTiltPermission(); }
      syncTilt();
    }));
    document.addEventListener("click", askTiltPermission, { once: true });
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener?.("change", applyTheme);

    document.addEventListener("keydown", (e) => {
      if (e.target.closest && e.target.closest("select, input, dialog")) return;
      if (e.key === "ArrowLeft") select(addDays(state.selected, -1));
      else if (e.key === "ArrowRight") select(addDays(state.selected, 1));
    });

    document.addEventListener("visibilitychange", () => { syncTilt(); if (!document.hidden) { offsetCache.clear(); tick(); renderToday(); wakeSky(); } });
    window.addEventListener("resize", wakeSky);
    phone.addEventListener?.("change", applyFocus);

    let deferredPrompt = null;
    window.addEventListener("beforeinstallprompt", (e) => {
      e.preventDefault(); deferredPrompt = e; $("installField").hidden = false;
    });
    $("installBtn").addEventListener("click", async () => {
      if (!deferredPrompt) return;
      deferredPrompt.prompt();
      try { await deferredPrompt.userChoice; } catch (e) { /* ignore */ }
      deferredPrompt = null; $("installField").hidden = true;
    });
    window.addEventListener("appinstalled", () => { $("installField").hidden = true; });
  }

  // ---------- Start ----------
  applyTheme();
  applyLook();
  lockPortrait();
  renderCities();
  setView("today");
  bind();
  bindSheet();
  renderAll();
  setInterval(tick, 1000);

  if ("serviceWorker" in navigator && (location.protocol === "https:" || location.hostname === "localhost" || location.hostname === "127.0.0.1")) {
    window.addEventListener("load", () => { navigator.serviceWorker.register("/sw.js").catch(() => {}); });
  }

  // Exposed for testing
  window.__vaktet = { dayTimes, CITIES, fmtTime, tzOffset, tipsFor };
})();
