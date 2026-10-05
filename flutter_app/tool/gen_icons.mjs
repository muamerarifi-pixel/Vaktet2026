// Draws every app icon from one design (needs Playwright's Chromium):  node flutter_app/tool/gen_icons.mjs
//
// The logo: an upright crescent opening upwards with a four-point star centred above it, mirror-symmetric left
// to right. Emerald green on deep blue.
//
// Writes:
//   icons/favicon.svg, icons/icon-192.png, icons/icon-512.png, icons/icon-maskable-512.png, icons/apple-touch-icon.png
//   flutter_app/android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  (adaptive icon foreground, 108dp)
//   flutter_app/android/app/src/main/res/mipmap-*/ic_launcher.png             (Android 7 and older)
import { writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require("playwright"); } catch { playwright = require("/opt/node-tools/node_modules/playwright"); }

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const res = resolve(root, "flutter_app/android/app/src/main/res");

// The mark, in a 32 × 32 box (the same paths as the header mark in index.html and svg_icon.dart).
export const CRESCENT = "M6.816 13.543A10 10 0 1 0 25.184 13.543A9.2 9.2 0 0 1 6.816 13.543Z";
export const STAR = "M16 7Q16.8 10.2 20 11Q16.8 11.8 16 15Q15.2 11.8 12 11Q15.2 10.2 16 7Z";
// the mark spans y 7 – 27.5: its middle is 17.25, so shift it up to centre it
const CENTRE = "translate(0 -1.25)";

const BG = `<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0E2350"/><stop offset="1" stop-color="#081633"/></linearGradient>
  <radialGradient id="glow" cx=".5" cy=".42" r=".55"><stop offset="0" stop-color="#10B981" stop-opacity=".22"/><stop offset="1" stop-color="#10B981" stop-opacity="0"/></radialGradient>`;
const EMERALD = `<linearGradient id="em" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#34D399"/><stop offset="1" stop-color="#059669"/></linearGradient>`;

function mark(scale, cx, cy) {
  // scale: px per mark unit; (cx, cy): where the mark's centre goes
  return `<g transform="translate(${cx - 16 * scale} ${cy - 16 * scale}) scale(${scale})"><g transform="${CENTRE}">
    <path d="${CRESCENT}" fill="url(#em)"/><path d="${STAR}" fill="#6EE7B7"/></g></g>`;
}

/** size px; markFrac: mark height / icon size; shape: "square" (rounded), "full" (edge to edge), "none" (transparent) */
function svg(size, markFrac, shape) {
  const scale = (size * markFrac) / 20.5; // the mark is 20.5 units tall
  const radius = shape === "square" ? size * 0.225 : 0;
  const bg = shape === "none" ? "" : `<rect width="${size}" height="${size}" rx="${radius}" fill="url(#bg)"/><rect width="${size}" height="${size}" rx="${radius}" fill="url(#glow)"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><defs>${BG}${EMERALD}</defs>${bg}${mark(scale, size / 2, size / 2)}</svg>`;
}

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
async function png(file, size, markFrac, shape) {
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg(size, markFrac, shape)}</body></html>`);
  await page.locator("svg").screenshot({ path: file, omitBackground: true });
}

writeFileSync(resolve(root, "icons/favicon.svg"), svg(64, 0.62, "square").replace(/\s*\n\s*/g, ""));
await png(resolve(root, "icons/icon-192.png"), 192, 0.6, "square");
await png(resolve(root, "icons/icon-512.png"), 512, 0.6, "square");
await png(resolve(root, "icons/icon-maskable-512.png"), 512, 0.46, "full"); // inside the 80% safe circle
await png(resolve(root, "icons/apple-touch-icon.png"), 180, 0.56, "full"); // iOS rounds the corners itself
for (const [name, f] of Object.entries({ mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 })) {
  // adaptive foreground: a 108dp canvas, the mark 44dp tall inside the 66dp safe circle
  await png(`${res}/mipmap-${name}/ic_launcher_foreground.png`, Math.round(108 * f), 44 / 108, "none");
  await png(`${res}/mipmap-${name}/ic_launcher.png`, Math.round(48 * f), 0.6, "square");
}
await browser.close();
console.log("icons written");
