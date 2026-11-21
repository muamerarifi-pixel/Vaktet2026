// Draws every app icon from one design (uses local Chrome/Edge via CDP or Playwright):
//   node flutter_app/tool/gen_icons.mjs
//
// The logo: a serene, minimalist human silhouette in sujood (prostration) sculpted in luminous
// pearl-ivory and warm champagne-gold, resting on a dark reflective horizon plane against a deep
// twilight emerald-teal atmospheric backdrop.
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

// Minimalist sujood (prostration) silhouette facing right in 512x512 space, resting on y = 358.
export const BODY_PATH =
  "M 96 356 C 90 356, 88 347, 95 343 L 146 322 C 145 282, 152 240, 174 214 C 192 193, 218 190, 242 204 C 278 224, 312 256, 338 292 C 344 300, 341 310, 332 313 C 320 317, 310 326, 314 337 C 318 345, 332 344, 342 347 C 348 349, 349 358, 340 358 L 296 358 C 286 358, 281 350, 284 340 L 293 310 C 272 288, 242 268, 216 264 C 202 262, 195 272, 198 290 L 206 342 C 208 352, 202 358, 190 358 L 96 358 Z";
export const BACK_RIM_PATH =
  "M 174 214 C 192 193, 218 190, 242 204 C 278 224, 312 256, 338 292";

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

  const figScale = isAdaptive ? 0.72 : isMaskable ? 0.88 : 1.04;
  const figTx = 256 - 252 * figScale;
  const figTy = isAdaptive ? 268 - 290 * figScale : isMaskable ? 266 - 290 * figScale : 268 - 290 * figScale;
  const horizonY = figTy + 358 * figScale;

  const defs = `<linearGradient id="darkSky" x1="0.15" y1="0" x2="0.85" y2="1"><stop offset="0%" stop-color="#0D2230"/><stop offset="48%" stop-color="#11323E"/><stop offset="100%" stop-color="#0A2029"/></linearGradient><radialGradient id="overheadGlow" cx="0.54" cy="${((horizonY - 145 * figScale) / S).toFixed(3)}" r="0.60"><stop offset="0%" stop-color="#FFE4A0" stop-opacity="0.28"/><stop offset="32%" stop-color="#48B8A6" stop-opacity="0.24"/><stop offset="72%" stop-color="#1A5463" stop-opacity="0.10"/><stop offset="100%" stop-color="#0A2029" stop-opacity="0"/></radialGradient><radialGradient id="horizonGlow" cx="0.50" cy="${(horizonY / S).toFixed(3)}" r="0.46"><stop offset="0%" stop-color="#FFE6AC" stop-opacity="0.26"/><stop offset="50%" stop-color="#3BA89A" stop-opacity="0.12"/><stop offset="100%" stop-color="#0A2029" stop-opacity="0"/></radialGradient><linearGradient id="groundGrad" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#091C25"/><stop offset="45%" stop-color="#06141C"/><stop offset="100%" stop-color="#040D13"/></linearGradient><radialGradient id="floorReflect" cx="0.5" cy="0" r="0.65"><stop offset="0%" stop-color="#FFE8B2" stop-opacity="0.28"/><stop offset="45%" stop-color="#4CC0B0" stop-opacity="0.11"/><stop offset="100%" stop-color="#040D13" stop-opacity="0"/></radialGradient><linearGradient id="horizonLine" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#6DD5C5" stop-opacity="0"/><stop offset="18%" stop-color="#6DD5C5" stop-opacity="0.32"/><stop offset="50%" stop-color="#FFE9B5" stop-opacity="0.88"/><stop offset="82%" stop-color="#6DD5C5" stop-opacity="0.32"/><stop offset="100%" stop-color="#6DD5C5" stop-opacity="0"/></linearGradient><linearGradient id="lightBody" x1="0.80" y1="0.04" x2="0.18" y2="1"><stop offset="0%" stop-color="#FFFFFF"/><stop offset="34%" stop-color="#FFF7E6"/><stop offset="72%" stop-color="#F1D499"/><stop offset="100%" stop-color="#C99E57"/></linearGradient><radialGradient id="lightHead" cx="0.62" cy="0.28" r="0.76"><stop offset="0%" stop-color="#FFFFFF"/><stop offset="48%" stop-color="#FFF6E2"/><stop offset="100%" stop-color="#DFB872"/></radialGradient><linearGradient id="topHighlight" x1="0" y1="0" x2="1" y2="0.65"><stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.35"/><stop offset="48%" stop-color="#FFFFFF" stop-opacity="0.98"/><stop offset="100%" stop-color="#FFF2CC" stop-opacity="0.45"/></linearGradient><linearGradient id="mirrorFade" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FFEEC4" stop-opacity="0.24"/><stop offset="45%" stop-color="#8ADCC8" stop-opacity="0.06"/><stop offset="100%" stop-color="#040D13" stop-opacity="0"/></linearGradient><linearGradient id="frameEdge" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.26"/><stop offset="30%" stop-color="#FFFFFF" stop-opacity="0.05"/><stop offset="75%" stop-color="#6DD5C5" stop-opacity="0.05"/><stop offset="100%" stop-color="#6DD5C5" stop-opacity="0.18"/></linearGradient><filter id="figShadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#020A0E" flood-opacity="0.58"/></filter><filter id="figGlow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="12"/></filter><filter id="reflectBlur" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="4.5"/></filter><clipPath id="cardClip"><rect width="${S}" height="${S}" rx="${rx}"/></clipPath><clipPath id="groundClip"><rect x="0" y="${horizonY.toFixed(1)}" width="${S}" height="${(S - horizonY).toFixed(1)}"/></clipPath>`;

  const bgLayer = `<rect width="${S}" height="${S}" fill="url(#darkSky)"/><rect width="${S}" height="${S}" fill="url(#overheadGlow)"/><rect width="${S}" height="${S}" fill="url(#horizonGlow)"/><rect x="0" y="${horizonY.toFixed(1)}" width="${S}" height="${(S - horizonY).toFixed(1)}" fill="url(#groundGrad)"/><rect x="0" y="${horizonY.toFixed(1)}" width="${S}" height="${(S - horizonY).toFixed(1)}" fill="url(#floorReflect)"/><line x1="0" y1="${horizonY.toFixed(1)}" x2="${S}" y2="${horizonY.toFixed(1)}" stroke="url(#horizonLine)" stroke-width="2.2"/>`;

  const fgLayer = `<g clip-path="url(#groundClip)" opacity="0.55" filter="url(#reflectBlur)"><g transform="translate(0 ${(2 * horizonY + 2).toFixed(2)}) scale(1 -0.38)"><g transform="translate(${figTx.toFixed(2)} ${figTy.toFixed(2)}) scale(${figScale.toFixed(4)})"><path d="${BODY_PATH}" fill="url(#mirrorFade)"/><circle cx="378" cy="329" r="28" fill="url(#mirrorFade)"/></g></g></g><g transform="translate(${figTx.toFixed(2)} ${figTy.toFixed(2)}) scale(${figScale.toFixed(4)})"><path d="${BODY_PATH}" fill="#FFE8B0" opacity="0.22" filter="url(#figGlow)"/><circle cx="378" cy="329" r="28" fill="#FFE8B0" opacity="0.26" filter="url(#figGlow)"/><g filter="url(#figShadow)"><path d="${BODY_PATH}" fill="url(#lightBody)"/><path d="${BACK_RIM_PATH}" fill="none" stroke="url(#topHighlight)" stroke-width="3.2" stroke-linecap="round"/><circle cx="378" cy="329" r="28" fill="url(#lightHead)"/><path d="M 358 309 A 28 28 0 0 1 401 314" fill="none" stroke="#FFFFFF" stroke-width="2.8" stroke-linecap="round" opacity="0.88"/></g></g>`;

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

/** Packs an array of { size, png } into a standard Windows multi-resolution ICO binary. */
function buildIcoBuffer(entries) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(entries.length, 4);

  const dirEntries = [];
  let offset = 6 + entries.length * 16;
  for (const { size, png } of entries) {
    const dir = Buffer.alloc(16);
    dir.writeUInt8(size >= 256 ? 0 : size, 0);
    dir.writeUInt8(size >= 256 ? 0 : size, 1);
    dir.writeUInt8(0, 2);
    dir.writeUInt8(0, 3);
    dir.writeUInt16LE(1, 4);
    dir.writeUInt16LE(32, 6);
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

  console.log("All dark sujood icons generated successfully.");
} finally {
  await renderer.close();
}
