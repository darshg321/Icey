// Which exercises and lessons the learner has finished, kept in localStorage.
const KEY = 'icey-progress';
const load = () => { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch { return {}; } };
let state = load();
const listeners = new Set();

export const progress = {
  isDone: id => !!state[id],
  markDone(id) {
    state[id] = Date.now();
    localStorage.setItem(KEY, JSON.stringify(state));
    for (const l of listeners) l();
  },
  unmark(id) {
    delete state[id];
    localStorage.setItem(KEY, JSON.stringify(state));
    for (const l of listeners) l();
  },
  onChange: fn => listeners.add(fn),
  reset() { state = {}; localStorage.removeItem(KEY); for (const l of listeners) l(); },
};
