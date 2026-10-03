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
    focus: store.get("focus", "0") === "1",
    tipsOn: store.get("tips", "1") === "1",
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
    const metas = document.querySelectorAll('meta[name="theme-color"]');
    const dark = state.theme === "dark" || (state.theme === "auto" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    metas.forEach((m) => m.setAttribute("content", dark ? "#0E1513" : "#EEF1EE"));
  }

  // Focus mode: hide the prayer list and keep only the countdown (today only).
  function applyFocus() {
    const on = state.focus && sameDay(state.selected, state.today);
    document.body.classList.toggle("is-focus", on);
    $("focusBtn").setAttribute("aria-pressed", String(state.focus));
    $("focusLabel").textContent = state.focus ? "Shfaq vaktet" : "Fshih vaktet";
  }

  // Daily tips, shown only while the prayer list is hidden. Two per day, never the same day to day:
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
  function applyTipsVisibility() {
    document.body.classList.toggle("no-tips", !state.tipsOn);
    $("tipsToggle").textContent = state.tipsOn ? "Fshih" : "Shfaq";
    $("tipsToggle").setAttribute("aria-expanded", String(state.tipsOn));
  }
  function renderTips() {
    const box = $("tipsList");
    const key = state.today.y + "-" + state.today.m + "-" + state.today.d;
    if (box.dataset.day === key) return;
    box.dataset.day = key;
    box.innerHTML = "";
    tipsFor(state.today).forEach((t) => {
      const a = document.createElement("article"); a.className = "tip" + (t.tag === "Si musliman" ? " is-muslim" : "");
      const g = document.createElement("span"); g.className = "tip-tag"; g.textContent = t.tag;
      const p = document.createElement("p"); p.textContent = t.text;
      a.append(g, p);
      box.appendChild(a);
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

  function renderToday() {
    const day = state.selected;
    const isToday = sameDay(day, state.today);
    $("dateText").textContent = longDate(day);
    $("hijriText").textContent = hijriText(day, state.hijriAdj) || String.fromCharCode(160);
    $("backToday").hidden = isToday;
    $("nextCard").hidden = !isToday;
    $("cityNote").textContent = cityNote();

    const rows = dayRows(day, state.city);
    const now = Date.now();
    let next = null;
    if (isToday) next = rows.find((r) => r.prayer && r.instant > now) || null;

    const list = $("times");
    list.innerHTML = "";
    rows.forEach((r) => {
      const li = document.createElement("li");
      if (isToday && r.instant <= now) li.classList.add("is-past");
      if (r === next) { li.classList.add("is-next"); li.setAttribute("aria-current", "time"); }
      const n = document.createElement("span"); n.className = "t-name"; n.textContent = r.name;
      const v = document.createElement("span"); v.className = "t-time"; v.textContent = fmtTime(r.local);
      li.append(n, v);
      list.appendChild(li);
    });

    $("alarmCard").hidden = true;
    $("focusBtn").hidden = !isToday;
    applyFocus();
    renderTips();
    if (isToday) {
      renderNextCard(day, rows, next, now);
      renderAlarm(day, rows, now);
      renderDayline(rows);
      tick();
    } else {
      state.nextInstant = null;
      state.altInstant = null;
      state.changeAt = null;
    }
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
  function updateOrb(now) {
    const rows = state.skyRows;
    if (!rows) return;
    const card = $("nextCard");
    const rise = rowOf(rows, "sunrise").instant, set = rowOf(rows, "maghrib").instant;
    let orb = "sun", p;
    if (now >= rise && now <= set) {
      p = (now - rise) / (set - rise);
    } else {
      orb = "moon";
      const from = now > set ? set : set - DAY_MS;
      const to = now > set ? rise + DAY_MS : rise;
      p = (now - from) / (to - from);
    }
    p = Math.min(1, Math.max(0, p));
    if (card.dataset.orb !== orb) card.dataset.orb = orb;
    card.style.setProperty("--ox", (0.12 + 0.76 * p).toFixed(4));
    card.style.setProperty("--oy", (0.34 - 0.24 * Math.sin(Math.PI * p)).toFixed(4));
    // the taller centred card (prayer list hidden) gets a flatter arc in its own band of sky above the text
    card.style.setProperty("--oyf", (0.16 - 0.08 * Math.sin(Math.PI * p)).toFixed(4));
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
    const now = Date.now();
    times.forEach((t) => {
      const s = document.createElement("span");
      s.style.left = (t.local / 1440 * 100).toFixed(2) + "%";
      if (t.instant <= now) s.classList.add("done");
      ticks.appendChild(s);
    });
    positionNow();
  }

  function positionNow() {
    const day = state.today;
    const midnight = utcOf(day) - tzOffset(day) * 60000;
    const frac = Math.min(1, Math.max(0, (Date.now() - midnight) / DAY_MS));
    const pct = (frac * 100).toFixed(2) + "%";
    $("daylineFill").style.width = pct;
    $("daylineNow").style.left = pct;
    updateOrb(Date.now());
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
  }

  function select(day) {
    state.selected = day;
    state.cursor = { y: day.y, m: day.m };
    renderAll();
  }

  // ---------- Clock ----------
  function tick() {
    const t = kosovoToday();
    if (!sameDay(t, state.today)) {
      const wasToday = sameDay(state.selected, state.today);
      state.today = t;
      if (wasToday) { state.selected = t; state.cursor = { y: t.y, m: t.m }; }
      renderAll();
      return;
    }
    if (state.nextInstant === null) return;
    const now = Date.now();
    if ((state.changeAt && now >= state.changeAt) || state.nextInstant - now <= 0) { renderToday(); return; }
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
    $("tipsToggle").addEventListener("click", () => {
      state.tipsOn = !state.tipsOn; store.set("tips", state.tipsOn ? "1" : "0"); applyTipsVisibility();
    });
    $("focusBtn").addEventListener("click", () => {
      state.focus = !state.focus; store.set("focus", state.focus ? "1" : "0"); applyFocus();
    });
    $("tabToday").addEventListener("click", () => setView("today"));
    $("tabMonth").addEventListener("click", () => setView("month"));

    const dlg = $("settings");
    $("settingsBtn").addEventListener("click", () => {
      document.querySelectorAll('input[name="theme"]').forEach((r) => { r.checked = r.value === state.theme; });
      document.querySelectorAll('input[name="hijri"]').forEach((r) => { r.checked = parseInt(r.value, 10) === state.hijriAdj; });
      document.querySelectorAll('input[name="alarm"]').forEach((r) => { r.checked = parseInt(r.value, 10) === state.alarmOffset; });
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
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener?.("change", applyTheme);

    document.addEventListener("keydown", (e) => {
      if (e.target.closest && e.target.closest("select, input, dialog")) return;
      if (e.key === "ArrowLeft") select(addDays(state.selected, -1));
      else if (e.key === "ArrowRight") select(addDays(state.selected, 1));
    });

    document.addEventListener("visibilitychange", () => { if (!document.hidden) { offsetCache.clear(); tick(); renderToday(); } });

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
  applyTipsVisibility();
  lockPortrait();
  renderCities();
  setView("today");
  bind();
  renderAll();
  setInterval(tick, 1000);

  if ("serviceWorker" in navigator && (location.protocol === "https:" || location.hostname === "localhost" || location.hostname === "127.0.0.1")) {
    window.addEventListener("load", () => { navigator.serviceWorker.register("/sw.js").catch(() => {}); });
  }

  // Exposed for testing
  window.__vaktet = { dayTimes, CITIES, fmtTime, tzOffset, tipsFor };
})();
