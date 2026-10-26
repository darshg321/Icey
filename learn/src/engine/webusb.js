// iceyprog.py, ported to WebUSB: loads a bitstream into the iCE40's SRAM
// through the FT2232H's channel A in MPSSE mode. Same pins and the same
// reset-before-CS ordering as firmware/tools/iceyprog.py:
//   ADBUS0 SCK  1 MOSI  2 MISO  3 CS  4 CRESET_B  5 CDONE
// On Linux the udev rule from firmware/tools/setup.sh is needed, same as for
// iceyprog.

const SCK = 1, MOSI = 2, CS = 8, CRESET = 16, CDONE = 32;
const DIR = SCK | MOSI | CS | CRESET;
const IFACE = 0, EP_OUT = 2, EP_IN = 1, INDEX = 1; // channel A

export const webUsbSupported = () => typeof navigator !== 'undefined' && !!navigator.usb;
const sleep = ms => new Promise(r => setTimeout(r, ms));

class Mpsse {
  constructor(dev) { this.dev = dev; }

  ctrl(request, value) {
    return this.dev.controlTransferOut({ requestType: 'vendor', recipient: 'device', request, value, index: INDEX });
  }

  async open() {
    const d = this.dev;
    await d.open();
    if (!d.configuration) await d.selectConfiguration(1);
    await d.claimInterface(IFACE);
    await this.ctrl(0, 0); // reset
    await this.ctrl(9, 2); // latency timer 2 ms
    await this.ctrl(0x0b, 0x0000); // bitmode: reset
    await this.ctrl(0x0b, 0x0200); // bitmode: MPSSE
    await this.ctrl(0, 1); await this.ctrl(0, 2); // purge rx/tx
    await sleep(20);
    // 60 MHz base clock, no adaptive/3-phase clocking, loopback off,
    // SCK = 60 MHz / ((1 + 4) * 2) = 6 MHz, same as iceyprog's default.
    await this.write([0x8a, 0x97, 0x8d, 0x85, 0x86, 4, 0]);
    this.pins = CS | CRESET;
    await this.setPins();
    // A bad command makes the MPSSE answer 0xFA; check it's alive and in sync.
    await this.write([0xab, 0x87]);
    const r = await this.read(2);
    if (r[0] !== 0xfa || r[1] !== 0xab) throw new Error('The FT2232H did not respond in MPSSE mode. Unplug and replug the board.');
  }

  write(bytes) { return this.dev.transferOut(EP_OUT, new Uint8Array(bytes)); }

  async read(n) {
    const out = [];
    const deadline = performance.now() + 1000;
    while (out.length < n) {
      const r = await this.dev.transferIn(EP_IN, 512);
      const b = new Uint8Array(r.data.buffer, r.data.byteOffset, r.data.byteLength);
      // Every 512-byte USB packet starts with 2 modem status bytes.
      for (let p = 0; p < b.length; p += 512) for (let i = p + 2; i < Math.min(p + 512, b.length); i++) out.push(b[i]);
      if (performance.now() > deadline) throw new Error('Timed out reading from the FT2232H');
    }
    return out.slice(0, n);
  }

  setPins() { return this.write([0x80, this.pins, DIR]); }
  async pin(mask, high) { this.pins = high ? this.pins | mask : this.pins & ~mask; await this.setPins(); }

  async cdone() {
    await this.write([0x81, 0x87]);
    return !!((await this.read(1))[0] & CDONE);
  }

  // Clock bytes out on MOSI, MSB first, data changing on the falling edge (SPI mode 0).
  async spiWrite(data) {
    for (let i = 0; i < data.length; i += 4096) {
      const chunk = data.subarray(i, i + 4096);
      const n = chunk.length - 1;
      const buf = new Uint8Array(3 + chunk.length);
      buf.set([0x11, n & 0xff, n >> 8]);
      buf.set(chunk, 3);
      await this.write(buf);
    }
  }

  async close() {
    try { await this.ctrl(0x0b, 0x0000); } catch {}
    try { await this.dev.releaseInterface(IFACE); } catch {}
    try { await this.dev.close(); } catch {}
  }
}

export async function uploadToIcey(bin, status = () => {}) {
  if (!webUsbSupported()) throw new Error('This browser has no WebUSB. Use Chrome or Edge, or download the .bin and run iceyprog.');
  let dev = (await navigator.usb.getDevices()).find(d => d.vendorId === 0x0403 && d.productId === 0x6010);
  if (!dev) {
    try {
      dev = await navigator.usb.requestDevice({ filters: [{ vendorId: 0x0403, productId: 0x6010 }] });
    } catch {
      throw new Error('No board picked. Plug Icey in by its PROGRAMMER USB-C port and try again.');
    }
  }
  const m = new Mpsse(dev);
  try {
    try {
      await m.open();
    } catch (e) {
      if (/Access denied|claim/i.test(e.message)) {
        throw new Error('The browser could not claim the FT2232H. On Linux, install the udev rule (firmware/tools/setup.sh) and replug. Close anything else using the board, like iceyprog or Icestudio.');
      }
      throw e;
    }
    status('Resetting the FPGA…');
    // Reset first, then CS low. CS low while CRESET_B rises = SPI slave mode.
    await m.pin(CRESET, false);
    await m.pin(CS, false);
    await sleep(1);
    await m.pin(CRESET, true);
    if (await m.cdone()) throw new Error('CDONE is stuck high while the FPGA is in reset.');
    await sleep(2);
    await m.pin(CS, true);
    await m.spiWrite(new Uint8Array(1)); // 8 dummy clocks with CS high
    await m.pin(CS, false);
    status(`Sending ${(bin.length / 1024).toFixed(0)} KB…`);
    await m.spiWrite(bin instanceof Uint8Array ? bin : new Uint8Array(bin));
    await m.pin(CS, true);
    await m.spiWrite(new Uint8Array(13)); // at least 49 more clocks to start the design
    return await m.cdone();
  } finally {
    await m.close();
  }
}
