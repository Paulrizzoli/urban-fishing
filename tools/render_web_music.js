#!/usr/bin/env node
// Renders the browser version's music (index.html, `Music`) to godot/audio/music_*.ogg.
//
// It runs the browser game's own Web Audio code, copied out of index.html as it is, in headless
// Chromium with an OfflineAudioContext: the same instruments, patterns, reverb, compressor and
// master level, so the Godot version plays the same tunes as the old game. The browser plays
// each style forever with some notes chosen at random; here each style is rendered as a long
// loop (BARS bars) with the reverb tail wrapped onto the start so it loops without a seam.
//
// Needs Node, Playwright (with its Chromium) and ffmpeg. Run from the repo root:
//     node tools/render_web_music.js
const fs = require("fs"), path = require("path"), os = require("os"), { execFileSync } = require("child_process");
const { chromium } = require("playwright");

const ROOT = path.join(__dirname, "..");
const OUT = path.join(ROOT, "godot", "audio");
const SR = 44100, BARS = 32, TAIL = 3;
const TARGET_DB = -21;         // average loudness of the set, to sit with the game's sound effects

const html = fs.readFileSync(path.join(ROOT, "index.html"), "utf8");
const a = html.indexOf("  function init(){"), b = html.indexOf("  function want(){");
if (a < 0 || b < 0) throw new Error("Could not find the Music code in index.html");
let engine = html.slice(a, b);
const pick = html.match(/^const pick = .*$/m)[0];
engine = engine.replace("ac = new AC();", "ac = new OfflineAudioContext(2, LEN, SR);");
if (!engine.includes("OfflineAudioContext")) throw new Error("index.html's init() changed; update this script");
const TEMPOS = Object.fromEntries([...engine.matchAll(/(\w+):\{ tempo:(\d+)/g)].map(m => [m[1], +m[2]]));

const page_src = `
${pick}
async function renderStyle(name, BARS, TAIL, SR){
  let ac = null, master = null, sfx = null, noise = null, verb = null;
  const fq = (s, base) => base * Math.pow(2, s / 12);
  const e = 60 / ${JSON.stringify(TEMPOS)}[name] / 4, loop = BARS * 16 * e;
  const LEN = Math.ceil((loop + TAIL) * SR);
${engine}
  init();
  master.gain.value = 0.45;                    // the level setOn(true) fades the music up to
  for (let st = 0; st < BARS * 16; st++) STY[name].step(st * e + 0.001, st % 16, Math.floor(st / 16));
  const buf = await ac.startRendering(), n = Math.round(loop * SR), chans = [];
  for (let c = 0; c < 2; c++){
    const d = buf.getChannelData(c), o = new Float32Array(n);
    o.set(d.subarray(0, n));
    for (let i = n; i < d.length && i - n < n; i++) o[i - n] += d[i];   // wrap the tail for a seamless loop
    chans.push(Array.from(o));
  }
  return chans;
}`;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  page.on("pageerror", e => console.error("page error:", e.message));
  await page.setContent("<html><body></body></html>");
  await page.addScriptTag({ content: page_src });
  const tracks = {};
  for (const name of Object.keys(TEMPOS)){
    tracks[name] = await page.evaluate(([n, bars, tail, sr]) => renderStyle(n, bars, tail, sr), [name, BARS, TAIL, SR]);
  }
  await browser.close();

  // one gain for the whole set keeps the tunes as loud as each other as they were in the browser
  const rms = x => Math.sqrt(x[0].reduce((s, v) => s + v * v, 0) / x[0].length);
  const dbs = Object.values(tracks).map(t => 20 * Math.log10(rms(t)));
  const avg = dbs.reduce((s, v) => s + v, 0) / dbs.length, gain = Math.pow(10, (TARGET_DB - avg) / 20);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "music-"));
  for (const [name, [l, r]] of Object.entries(tracks)){
    let g = gain, pk = 0;
    for (let i = 0; i < l.length; i++) pk = Math.max(pk, Math.abs(l[i]), Math.abs(r[i]));
    if (pk * g > 0.89) g = 0.89 / pk;
    const f = new Float32Array(l.length * 2);
    for (let i = 0; i < l.length; i++){ f[i * 2] = l[i] * g; f[i * 2 + 1] = r[i] * g; }
    const raw = path.join(tmp, name + ".f32");
    fs.writeFileSync(raw, Buffer.from(f.buffer));
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-f", "f32le", "-ar", String(SR), "-ac", "2", "-i", raw,
      "-c:a", "libvorbis", "-q:a", "5", path.join(OUT, "music_" + name + ".ogg")]);
    console.log(`music_${name}: ${(l.length / SR).toFixed(1)}s, ${(20 * Math.log10(rms([l]) * g)).toFixed(1)} dB`);
  }
  fs.rmSync(tmp, { recursive: true });
})();
