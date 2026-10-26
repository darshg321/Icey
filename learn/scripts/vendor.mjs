// Copies the YoWASP toolchains into public/yowasp so the site can load them at
// runtime without Vite touching them. nextpnr ships chip databases for every
// iCE40 (230 MB); Icey only needs the UP5K one, so we repack just that file
// into one gzipped tar and patch the loader to fetch it.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'public/yowasp');
const src = name => path.join(root, 'node_modules/@yowasp', name, 'gen');

function copyDir(from, to, skip = () => false) {
  fs.mkdirSync(to, { recursive: true });
  for (const f of fs.readdirSync(from)) if (!skip(f)) fs.copyFileSync(path.join(from, f), path.join(to, f));
}

// Minimal tar reader/writer (ustar, regular files and directories only).
function readTar(buf) {
  const files = [];
  let off = 0;
  while (off + 512 <= buf.length) {
    const h = buf.subarray(off, off + 512);
    if (h.every(b => b === 0)) break;
    const name = h.subarray(0, 100).toString().replace(/\0.*$/s, '');
    const prefix = h.subarray(345, 500).toString().replace(/\0.*$/s, '');
    const size = parseInt(h.subarray(124, 136).toString().replace(/\0.*$/s, '').trim() || '0', 8);
    const type = String.fromCharCode(h[156] || 48);
    files.push({ name: prefix ? `${prefix}/${name}` : name, type, data: buf.subarray(off + 512, off + 512 + size) });
    off += 512 + Math.ceil(size / 512) * 512;
  }
  return files;
}

function tarHeader(name, size, type) {
  const h = Buffer.alloc(512);
  h.write(name, 0, 100);
  h.write(type === '5' ? '0000755\0' : '0000644\0', 100);
  h.write('0000000\0', 108);
  h.write('0000000\0', 116);
  h.write(size.toString(8).padStart(11, '0') + '\0', 124);
  h.write('00000000000\0', 136);
  h.write('        ', 148);
  h.write(type, 156);
  h.write('ustar\0' + '00', 257);
  let sum = 0;
  for (const b of h) sum += b;
  h.write(sum.toString(8).padStart(6, '0') + '\0 ', 148);
  return h;
}

function writeTar(entries) {
  const parts = [];
  for (const { name, data, type } of entries) {
    parts.push(tarHeader(name, data ? data.length : 0, type));
    if (data) {
      parts.push(data);
      const pad = (512 - (data.length % 512)) % 512;
      if (pad) parts.push(Buffer.alloc(pad));
    }
  }
  parts.push(Buffer.alloc(1024));
  return Buffer.concat(parts);
}

// --- yosys: copied as is
copyDir(src('yosys'), path.join(out, 'yosys'));

// --- nextpnr-ice40 + icestorm tools
const pnrOut = path.join(out, 'nextpnr');
copyDir(src('nextpnr-ice40'), pnrOut, f => f.includes('-resources.'));
const chunks = fs.readdirSync(src('nextpnr-ice40')).filter(f => /resources\.\d+\.tar$/.test(f)).sort();
const whole = Buffer.concat(chunks.map(f => fs.readFileSync(path.join(src('nextpnr-ice40'), f))));
const files = readTar(whole);
const keep = files.filter(f => f.name === 'ice40' || f.name === 'ice40/' || f.name === 'ice40/chipdb-5k.bin');
if (!keep.some(f => f.name.endsWith('chipdb-5k.bin'))) throw new Error('chipdb-5k.bin not found in nextpnr resources');
const tar = writeTar(keep.map(f => ({ name: f.name, type: f.type, data: f.type === '5' ? null : f.data })));
const gz = zlib.gzipSync(tar, { level: 9 });
fs.writeFileSync(path.join(pnrOut, 'nextpnr-ice40-chipdb-5k.tgz.bin'), gz);

let bundle = fs.readFileSync(path.join(pnrOut, 'bundle.js'), 'utf8');
const pushes = /(\s*chunks\.push\(await fetch3\(new URL\("\.\/nextpnr-ice40-resources\.\d\.tar", import\.meta\.url\)\)\.then\(\(resp\) => resp\.arrayBuffer\(\)\)\);)+/;
if (!pushes.test(bundle)) throw new Error('nextpnr bundle layout changed; update scripts/vendor.mjs');
bundle = bundle.replace(pushes, `
  chunks.push(await fetch3(new URL("./nextpnr-ice40-chipdb-5k.tgz.bin", import.meta.url)).then((resp) => new Response(resp.body.pipeThrough(new DecompressionStream("gzip"))).arrayBuffer()));`);
bundle = bundle.replace(/var totalSize = \d+;/, m => {
  // The progress bar counts compressed bytes from the tar plus the wasm modules.
  const wasm = fs.readdirSync(pnrOut).filter(f => f.endsWith('.wasm')).reduce((n, f) => n + fs.statSync(path.join(pnrOut, f)).size, 0);
  return `var totalSize = ${gz.length + wasm};`;
});
fs.writeFileSync(path.join(pnrOut, 'bundle.js'), bundle);
console.log(`vendored yosys + nextpnr (chipdb-5k: ${(tar.length / 1e6).toFixed(1)} MB -> ${(gz.length / 1e6).toFixed(1)} MB gz)`);

// --- netlistsvg (browser bundle + gate skin) for the gate view
const vend = path.join(root, 'public/vendor');
fs.mkdirSync(vend, { recursive: true });
fs.copyFileSync(path.join(root, 'node_modules/netlistsvg/built/netlistsvg.bundle.js'), path.join(vend, 'netlistsvg.bundle.js'));
fs.copyFileSync(path.join(root, 'node_modules/netlistsvg/lib/default.svg'), path.join(vend, 'netlistsvg-skin.svg'));
fs.copyFileSync(path.join(root, 'node_modules/netlistsvg/node_modules/elkjs/lib/elk.bundled.js'), path.join(vend, 'elk.bundled.js'));
