// Interactive figures used inside lesson text via `@widget name {args}`.
const registry = {};
export const register = (name, fn) => { registry[name] = fn; };

export function mountWidgets(root) {
  for (const el of root.querySelectorAll('.widget[data-widget]')) {
    const fn = registry[el.dataset.widget];
    let args = {};
    try { args = JSON.parse(el.dataset.args || '{}'); } catch {}
    if (el.dataset.src !== undefined) args = { src: decodeURIComponent(el.dataset.src) };
    if (fn) fn(el, args); else el.textContent = `(unknown widget ${el.dataset.widget})`;
  }
}
