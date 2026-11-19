// Draws every app icon from one design (uses local Chrome/Edge via CDP or Playwright):
//   node flutter_app/tool/gen_icons.mjs
//
// The logo: Vaktet's signature upright crescent & four-point star sculpted in warm pearl-gold,
// floating with soft 3D depth above a luminous cerulean-to-teal dawn sky, subtle celestial orbital arc,
// layered Kosovo mountain silhouettes, and a tranquil reflective lake — inspired directly by the app's
// living sky homescreen and daily prayer times.
//
// Writes:
//   icons/favicon.svg, icons/icon-192.png, icons/icon-512.png, icons/icon-maskable-512.png, icons/apple-touch-icon.png
//   icons/app.ico, flutter_app/windows/runner/resources/app_icon.ico  (multi-size Windows ICO)
//   flutter_app/android/app/src/main/res/mipmap-*/ic_launcher_background.png  (adaptive icon background, 108dp)
//   flutter_app/android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  (adaptive icon foreground, 108dp)
//   flutter_app/android/app/src/main/res/mipmap-*/ic_launcher.png             (Android 7 and older, 48dp)
import { spawn } from "node:child_process";
import { existsSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const res = resolve(root, "flutter_app/android/app/src/main/res");

// The mark, in a 32 x 32 box (same core geometry as the header mark in index.html and svg_icon.dart).
export const CRESCENT = "M6.816 13.543A10 10 0 1 0 25.184 13.543A9.2 9.2 0 0 1 6.816 13.543Z";
export const STAR = "M16 7Q16.8 10.2 20 11Q16.8 11.8 16 15Q15.2 11.8 12 11Q15.2 10.2 16 7Z";

/**
 * Generates the SVG for Vaktet's icon.
 * @param {number} size Output pixel size
 * @param {"square"|"full"|"maskable"|"background"|"foreground"} mode Layout/mask mode
 */
export function buildIconSvg(size, mode = "square") {
  const S = 512;
  const isAdaptive = mode === "background" || mode === "foreground";
  const isMaskable = mode === "maskable";
  const rx = mode === "square" ? S * 0.225 : 0;

  // Balanced framing per platform safe-zone
  const horizonY = isAdaptive ? 334 : isMaskable ? 362 : 374;
  const markScale = isAdaptive ? 8.3 : isMaskable ? 10.8 : 12.4;
  const markCx = 256;
  const markCy = isAdaptive ? 224 : isMaskable ? 212 : 196;

  // Whisper-thin celestial orbital arc hinting at the sun/moon passage across prayer times
  const arcR = isAdaptive ? 148 : 206;
  const arcCy = horizonY + 14;

  const defs = `<linearGradient id="sky" x1="0.08" y1="0" x2="0.18" y2="1"><stop offset="0%" stop-color="#174975"/><stop offset="32%" stop-color="#1E6E8B"/><stop offset="64%" stop-color="#359A98"/><stop offset="100%" stop-color="#84D3B6"/></linearGradient><radialGradient id="topDome" cx="0.5" cy="0.10" r="0.60"><stop offset="0%" stop-color="#85EDE0" stop-opacity="0.22"/><stop offset="100%" stop-color="#85EDE0" stop-opacity="0"/></radialGradient><radialGradient id="dawnGlow" cx="0.5" cy="${((horizonY - 22) / S).toFixed(3)}" r="0.54"><stop offset="0%" stop-color="#FFF2C6" stop-opacity="0.90"/><stop offset="30%" stop-color="#F7C97E" stop-opacity="0.48"/><stop offset="66%" stop-color="#60C5B4" stop-opacity="0.15"/><stop offset="100%" stop-color="#359A98" stop-opacity="0"/></radialGradient><linearGradient id="arcStroke" x1="0" y1="0.6" x2="1" y2="0.6"><stop offset="0%" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="22%" stop-color="#DFF7F0" stop-opacity="0.18"/><stop offset="50%" stop-color="#FFF5D6" stop-opacity="0.28"/><stop offset="78%" stop-color="#DFF7F0" stop-opacity="0.18"/><stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient><linearGradient id="mtnBack" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#286D84" stop-opacity="0.68"/><stop offset="100%" stop-color="#184C62" stop-opacity="0.92"/></linearGradient><linearGradient id="mtnFront" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#164B60"/><stop offset="100%" stop-color="#0D3445"/></linearGradient><linearGradient id="mtnRim" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#9BE6D6" stop-opacity="0.08"/><stop offset="50%" stop-color="#FFECB8" stop-opacity="0.55"/><stop offset="100%" stop-color="#9BE6D6" stop-opacity="0.08"/></linearGradient><linearGradient id="lake" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#19526A"/><stop offset="40%" stop-color="#123E54"/><stop offset="100%" stop-color="#0B2A3C"/></linearGradient><radialGradient id="lakeGlow" cx="0.5" cy="0" r="0.72"><stop offset="0%" stop-color="#FFECB8" stop-opacity="0.56"/><stop offset="42%" stop-color="#6ACBB8" stop-opacity="0.22"/><stop offset="100%" stop-color="#0B2A3C" stop-opacity="0"/></radialGradient><linearGradient id="shoreLine" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#8AD8C8" stop-opacity="0.06"/><stop offset="28%" stop-color="#DDF6EC" stop-opacity="0.45"/><stop offset="50%" stop-color="#FFF5D4" stop-opacity="0.92"/><stop offset="72%" stop-color="#DDF6EC" stop-opacity="0.45"/><stop offset="100%" stop-color="#8AD8C8" stop-opacity="0.06"/></linearGradient><radialGradient id="markHalo" cx="0.5" cy="0.50" r="0.52"><stop offset="0%" stop-color="#FFF6D6" stop-opacity="0.42"/><stop offset="52%" stop-color="#A8F0DF" stop-opacity="0.14"/><stop offset="100%" stop-color="#A8F0DF" stop-opacity="0"/></radialGradient><linearGradient id="crescentFill" x1="0.22" y1="0.04" x2="0.78" y2="1"><stop offset="0%" stop-color="#FFFFFF"/><stop offset="32%" stop-color="#FFF8E6"/><stop offset="68%" stop-color="#F6D590"/><stop offset="100%" stop-color="#D29A48"/></linearGradient><linearGradient id="crescentRim" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.98"/><stop offset="48%" stop-color="#FFF9EB" stop-opacity="0.30"/><stop offset="100%" stop-color="#FFE9B5" stop-opacity="0.72"/></linearGradient><radialGradient id="starFill" cx="0.5" cy="0.45" r="0.58"><stop offset="0%" stop-color="#FFFFFF"/><stop offset="62%" stop-color="#FFF8E5"/><stop offset="100%" stop-color="#F2D18C"/></radialGradient><linearGradient id="frameEdge" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.28"/><stop offset="28%" stop-color="#FFFFFF" stop-opacity="0.05"/><stop offset="78%" stop-color="#80E2CC" stop-opacity="0.04"/><stop offset="100%" stop-color="#80E2CC" stop-opacity="0.18"/></linearGradient><filter id="markShadow" x="-45%" y="-45%" width="190%" height="190%"><feDropShadow dx="0" dy="1.05" stdDeviation="1.2" flood-color="#062030" flood-opacity="0.38"/></filter><filter id="starGlow" x="-90%" y="-90%" width="280%" height="280%"><feGaussianBlur stdDeviation="1.15"/></filter><filter id="waterReflectBlur" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="7"/></filter><clipPath id="cardClip"><rect width="${S}" height="${S}" rx="${rx}"/></clipPath>`;

  const hy = horizonY;
  const backMtn = `M-12 ${hy + 8} L-12 ${hy - 46} Q38 ${hy - 68} 78 ${hy - 86} Q106 ${hy - 98} 142 ${hy - 64} Q188 ${hy - 30} 256 ${hy - 22} Q318 ${hy - 28} 358 ${hy - 72} Q392 ${hy - 102} 428 ${hy - 74} Q472 ${hy - 48} 524 ${hy - 40} L524 ${hy + 8} Z`;
  const frontMtn = `M-12 ${hy + 6} L-12 ${hy - 20} Q56 ${hy - 48} 118 ${hy - 28} Q178 ${hy - 6} 256 ${hy - 2} Q334 ${hy - 6} 394 ${hy - 30} Q456 ${hy - 50} 524 ${hy - 16} L524 ${hy + 6} Z`;
  const frontRim = `M-12 ${hy - 20} Q56 ${hy - 48} 118 ${hy - 28} Q178 ${hy - 6} 256 ${hy - 2} Q334 ${hy - 6} 394 ${hy - 30} Q456 ${hy - 50} 524 ${hy - 16}`;
  const celestialArc = `M${256 - arcR} ${arcCy} A${arcR} ${arcR} 0 0 1 ${256 + arcR} ${arcCy}`;

  const dashScale = isAdaptive ? 0.78 : 1.0;
  const d = (w) => ((w * dashScale) / 2).toFixed(1);
  const dy = (off) => (hy + off * (isAdaptive ? 0.85 : 1.0)).toFixed(1);

  const bgLayer = `<rect width="${S}" height="${S}" fill="url(#sky)"/><rect width="${S}" height="${S}" fill="url(#topDome)"/><rect width="${S}" height="${S}" fill="url(#dawnGlow)"/><path d="${celestialArc}" fill="none" stroke="url(#arcStroke)" stroke-width="2.2" stroke-dasharray="6 9" stroke-linecap="round"/><circle cx="${isAdaptive ? 156 : 112}" cy="${isAdaptive ? 154 : 106}" r="2.6" fill="#FFF9E6" opacity="0.48"/><circle cx="${isAdaptive ? 364 : 404}" cy="${isAdaptive ? 168 : 124}" r="2.1" fill="#E3FAF3" opacity="0.40"/><circle cx="${isAdaptive ? 184 : 152}" cy="${isAdaptive ? 204 : 158}" r="1.5" fill="#E3FAF3" opacity="0.28"/><circle cx="${isAdaptive ? 336 : 362}" cy="${isAdaptive ? 142 : 94}" r="1.6" fill="#FFF9E6" opacity="0.30"/><path d="${backMtn}" fill="url(#mtnBack)"/><path d="${frontMtn}" fill="url(#mtnFront)"/><path d="${frontRim}" fill="none" stroke="url(#mtnRim)" stroke-width="2.0" stroke-linecap="round"/><rect x="0" y="${hy}" width="${S}" height="${S - hy}" fill="url(#lake)"/><rect x="0" y="${hy}" width="${S}" height="${S - hy}" fill="url(#lakeGlow)"/><ellipse cx="256" cy="${dy(24)}" rx="${(48 * dashScale).toFixed(1)}" ry="${(20 * dashScale).toFixed(1)}" fill="#FFE9B5" opacity="0.22" filter="url(#waterReflectBlur)"/><line x1="0" y1="${hy}" x2="${S}" y2="${hy}" stroke="url(#shoreLine)" stroke-width="2.2"/><g stroke-linecap="round"><line x1="${(256 - +d(92)).toFixed(1)}" y1="${dy(18)}" x2="${(256 + +d(92)).toFixed(1)}" y2="${dy(18)}" stroke="#FFF5D4" stroke-width="4.4" opacity="0.68"/><line x1="${(256 - +d(62)).toFixed(1)}" y1="${dy(36)}" x2="${(256 + +d(62)).toFixed(1)}" y2="${dy(36)}" stroke="#FFECB8" stroke-width="3.6" opacity="0.48"/><line x1="${(256 - +d(38)).toFixed(1)}" y1="${dy(54)}" x2="${(256 + +d(38)).toFixed(1)}" y2="${dy(54)}" stroke="#C8F0E4" stroke-width="3.0" opacity="0.32"/><line x1="${(256 - +d(20)).toFixed(1)}" y1="${dy(70)}" x2="${(256 + +d(20)).toFixed(1)}" y2="${dy(70)}" stroke="#9CE2D4" stroke-width="2.4" opacity="0.20"/></g>`;

  const fgLayer = `<g transform="translate(${(markCx - 16 * markScale).toFixed(2)} ${(markCy - 16 * markScale).toFixed(2)}) scale(${markScale.toFixed(4)})"><g transform="translate(0 -1.25)"><ellipse cx="16" cy="17.2" rx="14.5" ry="13.5" fill="url(#markHalo)"/><g filter="url(#markShadow)"><path d="${CRESCENT}" fill="url(#crescentFill)"/><path d="${CRESCENT}" fill="none" stroke="url(#crescentRim)" stroke-width="0.28"/></g><path d="${STAR}" fill="#FFF8E2" opacity="0.70" filter="url(#starGlow)"/><g filter="url(#markShadow)"><path d="${STAR}" fill="url(#starFill)"/></g></g></g>`;

  const frameStroke = mode === "square"
    ? `<rect x="1.25" y="1.25" width="${S - 2.5}" height="${S - 2.5}" rx="${rx - 0.75}" fill="none" stroke="url(#frameEdge)" stroke-width="2.5"/>`
    : "";

  const content = mode === "background"
    ? bgLayer
    : mode === "foreground"
      ? fgLayer
      : `${bgLayer}${fgLayer}`;

  const wrapped = mode === "square"
    ? `<g clip-path="url(#cardClip)">${content}</g>${frameStroke}`
    : content;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${S} ${S}"><defs>${defs}</defs>${wrapped}</svg>`;
}

/** Packs an array of { size, pngBuffer } into a standard Windows multi-resolution ICO binary. */
function buildIcoBuffer(entries) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // type: 1 = ICO
  header.writeUInt16LE(entries.length, 4);

  const dirEntries = [];
  let offset = 6 + entries.length * 16;
  for (const { size, png } of entries) {
    const dir = Buffer.alloc(16);
    dir.writeUInt8(size >= 256 ? 0 : size, 0);
    dir.writeUInt8(size >= 256 ? 0 : size, 1);
    dir.writeUInt8(0, 2); // palette
    dir.writeUInt8(0, 3); // reserved
    dir.writeUInt16LE(1, 4); // planes
    dir.writeUInt16LE(32, 6); // bpp
    dir.writeUInt32LE(png.length, 8);
    dir.writeUInt32LE(offset, 12);
    dirEntries.push(dir);
    offset += png.length;
  }
  return Buffer.concat([header, ...dirEntries, ...entries.map((e) => e.png)]);
}

function findBrowser() {
  const candidates = [
    process.env.CHROME_PATH,
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ].filter(Boolean);
  return candidates.find((p) => existsSync(p));
}

async function createRenderer() {
  // Prefer Playwright if installed, otherwise use local Chrome/Edge via native CDP WebSocket
  try {
    let pw;
    try { pw = require("playwright"); } catch { pw = require("/opt/node-tools/node_modules/playwright"); }
    const browser = await pw.chromium.launch();
    const page = await browser.newPage();
    return {
      async renderSvg(svgMarkup, size) {
        await page.setViewportSize({ width: size, height: size });
        await page.setContent(`<html><body style="margin:0;background:transparent">${svgMarkup}</body></html>`);
        return await page.locator("svg").screenshot({ omitBackground: true });
      },
      async close() { await browser.close(); },
    };
  } catch {
    const bin = findBrowser();
    if (!bin) throw new Error("No Playwright or local Chrome/Edge binary found to render SVG icons.");
    const proc = spawn(bin, [
      "--headless=new",
      "--disable-gpu",
      "--no-sandbox",
      "--remote-debugging-port=0",
      "about:blank",
    ], { stdio: ["ignore", "pipe", "pipe"] });

    const wsUrl = await new Promise((resolveUrl, rejectUrl) => {
      let buf = "";
      const onData = (d) => {
        buf += d.toString();
        const m = buf.match(/DevTools listening on (ws:\/\/[^\s]+)/);
        if (m) resolveUrl(m[1]);
      };
      proc.stderr.on("data", onData);
      proc.stdout.on("data", onData);
      proc.on("error", rejectUrl);
      setTimeout(() => rejectUrl(new Error("Timed out waiting for browser DevTools")), 15000);
    });

    const port = new URL(wsUrl).port;
    const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    const pageTarget = targets.find((t) => t.type === "page");
    const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);
    await new Promise((r) => ws.addEventListener("open", r));

    let id = 0;
    const pending = new Map();
    ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && pending.has(msg.id)) {
        const { res, rej } = pending.get(msg.id);
        pending.delete(msg.id);
        if (msg.error) rej(new Error(msg.error.message));
        else res(msg.result);
      }
    });
    const send = (method, params = {}) => new Promise((res, rej) => {
      const mid = ++id;
      pending.set(mid, { res, rej });
      ws.send(JSON.stringify({ id: mid, method, params }));
    });

    await send("Page.enable");
    await send("Emulation.setDefaultBackgroundColorOverride", { color: { r: 0, g: 0, b: 0, a: 0 } });
    const { frameTree } = await send("Page.getFrameTree");
    const frameId = frameTree.frame.id;

    return {
      async renderSvg(svgMarkup, size) {
        await send("Emulation.setDeviceMetricsOverride", { width: size, height: size, deviceScaleFactor: 1, mobile: false });
        await send("Page.setDocumentContent", {
          frameId,
          html: `<html><body style="margin:0;overflow:hidden;background:transparent">${svgMarkup}</body></html>`,
        });
        await new Promise((r) => setTimeout(r, 40));
        const { data } = await send("Page.captureScreenshot", { format: "png", fromSurface: true, omitBackground: true });
        return Buffer.from(data, "base64");
      },
      async close() {
        ws.close();
        proc.kill();
      },
    };
  }
}

const renderer = await createRenderer();
try {
  async function writePng(file, size, mode) {
    const buf = await renderer.renderSvg(buildIconSvg(size, mode), size);
    writeFileSync(file, buf);
    return buf;
  }

  // 1. Web / PWA icons
  writeFileSync(resolve(root, "icons/favicon.svg"), buildIconSvg(64, "square"));
  await writePng(resolve(root, "icons/icon-192.png"), 192, "square");
  await writePng(resolve(root, "icons/icon-512.png"), 512, "square");
  await writePng(resolve(root, "icons/icon-maskable-512.png"), 512, "maskable");
  await writePng(resolve(root, "icons/apple-touch-icon.png"), 180, "full");

  // 2. Android adaptive & legacy launcher icons
  for (const [name, f] of Object.entries({ mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 })) {
    const adaptivePx = Math.round(108 * f);
    const legacyPx = Math.round(48 * f);
    await writePng(`${res}/mipmap-${name}/ic_launcher_background.png`, adaptivePx, "background");
    await writePng(`${res}/mipmap-${name}/ic_launcher_foreground.png`, adaptivePx, "foreground");
    await writePng(`${res}/mipmap-${name}/ic_launcher.png`, legacyPx, "square");
  }

  // 3. Multi-resolution Windows ICO (16..256px) for MSI installer & native Runner executable
  const icoSizes = [16, 24, 32, 48, 64, 128, 256];
  const icoEntries = [];
  for (const sz of icoSizes) {
    const png = await renderer.renderSvg(buildIconSvg(sz, "square"), sz);
    icoEntries.push({ size: sz, png });
  }
  const icoBuf = buildIcoBuffer(icoEntries);
  writeFileSync(resolve(root, "icons/app.ico"), icoBuf);
  writeFileSync(resolve(root, "flutter_app/windows/runner/resources/app_icon.ico"), icoBuf);

  console.log("All icons (Web, Android adaptive & legacy, Windows multi-size ICO) generated successfully.");
} finally {
  await renderer.close();
}
