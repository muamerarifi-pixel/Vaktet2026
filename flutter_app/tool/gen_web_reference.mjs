// Records what the original web app shows at many fake instants, so the Dart port can be tested against it.
//
//   node tool/gen_web_reference.mjs <web-app-dir> <out.json> [thin]
//
// Needs Playwright (with Chromium). The web app is served from <web-app-dir>; its clock is faked,
// and the page's visible text is read back. Run it from the repo root's web files.
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");

const [webDir, outFile, thinArg] = process.argv.slice(2);
const thin = parseInt(thinArg || "1", 10);

const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".woff2": "font/woff2", ".png": "image/png", ".svg": "image/svg+xml", ".webmanifest": "application/manifest+json" };
const server = http.createServer((req, res) => {
  const p = path.join(webDir, req.url === "/" ? "index.html" : decodeURIComponent(req.url.split("?")[0]));
  fs.readFile(p, (err, buf) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { "content-type": types[path.extname(p)] || "application/octet-stream" });
    res.end(buf);
  });
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const url = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch();
const context = await browser.newContext({ timezoneId: "Asia/Tokyo", viewport: { width: 390, height: 844 }, serviceWorkers: "block" });
const page = await context.newPage();
await page.goto(url);
await page.waitForFunction(() => !!window.__vaktet);

const snapshots = await page.evaluate(({ thin }) => {
  const RealDate = Date;
  let fixed = null;
  class FakeDate extends RealDate {
    constructor(...a) { if (a.length === 0 && fixed !== null) super(fixed); else super(...a); }
    static now() { return fixed !== null ? fixed : RealDate.now(); }
  }
  window.Date = FakeDate;

  const V = window.__vaktet;
  const $ = (id) => document.getElementById(id);
  const cityEl = $("city");
  const setRadio = (name, value) => {
    const r = [...document.querySelectorAll(`input[name="${name}"]`)].find((x) => x.value === String(value));
    r.checked = true; r.dispatchEvent(new Event("change"));
  };
  const text = (id) => $(id).textContent;

  const fullDays = ["2026-01-01", "2026-02-28", "2026-03-28", "2026-03-29", "2026-03-30", "2026-06-19", "2026-10-24", "2026-10-25", "2026-10-26", "2026-12-31", "2027-01-01", "2027-03-28", "2027-10-31", "2028-02-29", "2028-03-26", "2028-10-29"];
  const sparseDays = [];
  for (let t = Date.UTC(2026, 0, 3); t < Date.UTC(2027, 0, 1); t += 9 * 86400000) sparseDays.push(new RealDate(t).toISOString().slice(0, 10));
  const plan = [];
  fullDays.forEach((d) => ["kosove", "prishtine", "dragash"].forEach((c) => plan.push({ d, c, full: true })));
  sparseDays.forEach((d, i) => plan.push({ d, c: ["kosove", "peje", "gjilan", "prizren"][i % 4], full: false }));

  const out = [];
  let n = 0;
  const alarms = [15, 30, 45, 60];
  const adjs = [-2, -1, 0, 1, 2];
  const dayTipsDone = new Set();
  const tips = {};
  for (const p of plan) {
    const [y, m, d] = p.d.split("-").map(Number);
    const city = V.CITIES.find((c) => c.id === p.c);
    const times = V.dayTimes({ y, m, d }, city);
    const probes = [];
    const base = Date.UTC(y, m - 1, d);
    times.forEach((t) => [-90000, -1000, 0, 1000, 61000].forEach((o) => probes.push(t.instant + o)));
    [[2, 15], [3, -10], [5, -15]].forEach(([i, mins]) => [-1000, 0, 1000].forEach((o) => probes.push(times[i].instant + mins * 60000 + o)));
    [30000, 12 * 3600000, 23 * 3600000 + 59 * 60000 + 30000].forEach((o) => probes.push(base - 3600000 + o));
    const chosen = p.full ? probes : probes.filter((_, i) => i % 3 === 0);
    for (const instant of chosen) {
      n++;
      if (n % thin !== 0) continue;
      fixed = instant;
      if (cityEl.value !== p.c) { cityEl.value = p.c; cityEl.dispatchEvent(new Event("change")); }
      setRadio("alarm", alarms[n % 4]);
      setRadio("hijri", adjs[n % 5]);
      document.dispatchEvent(new Event("visibilitychange"));
      const card = $("nextCard");
      const snap = {
        t: instant,
        c: p.c,
        adj: adjs[n % 5],
        al: alarms[n % 4],
        date: text("dateText"),
        hijri: text("hijriText"),
        intro: text("nextIntro"),
        name: text("nextName"),
        time: text("nextTime"),
        cd: text("countdown"),
        cdl: text("countdownLabel"),
        forbid: card.classList.contains("is-forbidden"),
        alt: $("nextAlt").hidden ? null : [text("nextAltText"), text("nextAltCount")],
        alarm: $("alarmCard").hidden ? null : [text("alarmTime"), text("alarmSub")],
        rows: [...document.querySelectorAll("#times li")].map((li) => [li.querySelector(".t-name").textContent, li.querySelector(".t-time").textContent, li.classList.contains("is-next") ? "n" : li.classList.contains("is-past") ? "p" : ""]),
        note: text("cityNote"),
        phase: document.body.dataset.phase,
        orb: card.dataset.orb,
        ox: card.style.getPropertyValue("--ox"),
        oy: card.style.getPropertyValue("--oy"),
        oyf: card.style.getPropertyValue("--oyf"),
        oyz: card.style.getPropertyValue("--oyz"),
        ticks: [...document.querySelectorAll("#daylineTicks span")].map((s) => [s.style.left, s.classList.contains("done")]),
        fill: $("daylineFill").style.width,
      };
      out.push(snap);
      const key = snap.date; // tips are those of the fake clock's "today"
      if (!dayTipsDone.has(key)) {
        dayTipsDone.add(key);
        tips[key] = [...document.querySelectorAll("#tipsList .tip")].map((a) => [a.querySelector(".tip-tag").textContent, a.querySelector("p").textContent]);
      }
    }
  }
  return { snapshots: out, tips };
}, { thin });

// Month table for every city, a few months (also checks the Dreka column and the Feb 29 rule)
const months = await page.evaluate(() => {
  const V = window.__vaktet;
  const out = {};
  for (const c of V.CITIES) for (const [y, m] of [[2026, 1], [2026, 3], [2026, 10], [2028, 2], [2027, 12]]) {
    const days = new Date(Date.UTC(y, m, 0)).getUTCDate();
    const rows = [];
    for (let d = 1; d <= days; d++) rows.push(V.dayTimes({ y, m, d }, c).map((t) => V.fmtTime(t.local)));
    out[`${c.id}:${y}-${m}`] = rows;
  }
  return out;
});

fs.writeFileSync(outFile, JSON.stringify({ generatedFrom: "web app (index.html, app.js)", ...snapshots, months }));
console.log("snapshots", snapshots.snapshots.length, "tip days", Object.keys(snapshots.tips).length, "->", outFile);
await browser.close();
server.close();
