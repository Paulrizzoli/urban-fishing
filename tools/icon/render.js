// Renders an SVG to a PNG of the given size with Chromium (Playwright).
// usage: node render.js <in.svg> <out.png> <size>
const { chromium } = require('playwright'); const fs=require('fs');
(async()=>{ const [svg,out,size]=process.argv.slice(2); const b=await chromium.launch(); const p=await b.newPage({viewport:{width:+size,height:+size}});
 const s=fs.readFileSync(svg,'utf8').replace(/width="512" height="512"/,`width="${size}" height="${size}"`);
 await p.setContent(`<html><body style="margin:0;background:transparent">${s}</body></html>`);
 await p.locator('svg').screenshot({path:out,omitBackground:true}); await b.close();})();
