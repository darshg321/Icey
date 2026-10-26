// Checks shared by the chip path's clocked sessions.

// Run lengths of a 1-bit output over n clocks.
export function runs(t, port, n) {
  const out = [];
  let last = t.get(port), len = 0;
  for (let i = 0; i < n; i++) {
    t.tick();
    const v = t.get(port);
    len++;
    if (v !== last) { out.push({ v: last, len }); last = v; len = 0; }
  }
  return out;
}

// No `reg x = ...` and no initial blocks: a real chip ignores them.
export function noInitialValues(t) {
  const decl = t.code.match(/\breg\b[^;,()]*=[^;,]*/);
  t.ok(!decl, `Remove the starting value from "${decl?.[0].trim()}" and set it in the reset instead. A real chip ignores starting values.`);
  t.ok(!/\binitial\b/.test(t.code), 'Remove the initial block: a real chip ignores it. Use the reset instead.');
}

// Power up with random register contents, then hold reset (active low) on `port`.
export function powerUp(t, port = 'rst_n', clocks = 4) {
  t.sim.scramble();
  t.set(port, 0);
  t.tick(clocks);
  t.set(port, 1);
}
