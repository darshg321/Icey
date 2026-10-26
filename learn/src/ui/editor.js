import { EditorView, basicSetup } from 'codemirror';
import { EditorState, Compartment } from '@codemirror/state';
import { keymap } from '@codemirror/view';
import { StreamLanguage, HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { verilog } from '@codemirror/legacy-modes/mode/verilog';
import { setDiagnostics } from '@codemirror/lint';
import { indentWithTab } from '@codemirror/commands';
import { tags as t } from '@lezer/highlight';

const style = HighlightStyle.define([
  { tag: t.keyword, color: '#c4a7ff' },
  { tag: [t.typeName, t.definition(t.variableName)], color: '#8fb4ff' },
  { tag: t.number, color: '#b5d99c' },
  { tag: t.string, color: '#b5d99c' },
  { tag: t.comment, color: '#7c8089', fontStyle: 'italic' },
  { tag: t.meta, color: '#e6a17a' },
  { tag: [t.operator, t.punctuation], color: '#b4b8c0' },
  { tag: t.variableName, color: '#e7e7e9' },
  { tag: t.atom, color: '#e5b450' },
]);

const theme = EditorView.theme({
  '&': { height: '100%', fontSize: '14px', backgroundColor: '#16171a', color: '#e7e7e9' },
  '.cm-scroller': { fontFamily: 'var(--mono)', lineHeight: '1.55' },
  '.cm-gutters': { backgroundColor: '#121316', color: '#5c6068', border: 'none' },
  '.cm-activeLine': { backgroundColor: '#ffffff08' },
  '.cm-activeLineGutter': { backgroundColor: '#ffffff0c', color: '#c8ccd4' },
  '.cm-cursor': { borderLeftColor: '#8bd5a0' },
  '&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection': { backgroundColor: '#3b4a6b88 !important' },
  '.cm-tooltip': { background: '#1d1f23', color: '#e7e7e9', border: '1px solid #33363c' },
}, { dark: true });

export function createEditor(parent, { doc = '', onRun, onChange } = {}) {
  const readOnly = new Compartment();
  const view = new EditorView({
    parent,
    state: EditorState.create({
      doc,
      extensions: [
        basicSetup,
        keymap.of([
          { key: 'Mod-Enter', run: () => { onRun && onRun(); return true; } },
          { key: 'Shift-Enter', run: () => { onRun && onRun(); return true; } },
          indentWithTab,
        ]),
        StreamLanguage.define(verilog),
        syntaxHighlighting(style),
        theme,
        readOnly.of(EditorState.readOnly.of(false)),
        EditorView.updateListener.of(u => { if (u.docChanged && onChange) onChange(view.state.doc.toString()); }),
      ],
    }),
  });
  return {
    view,
    get value() { return view.state.doc.toString(); },
    set value(v) { view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: v } }); },
    showDiagnostics(diags) {
      const doc = view.state.doc;
      const list = [];
      for (const d of diags) {
        if (!d.line || d.line > doc.lines) continue;
        const line = doc.line(d.line);
        list.push({ from: line.from, to: Math.max(line.to, line.from), severity: d.severity, message: d.message });
      }
      view.dispatch(setDiagnostics(view.state, list));
    },
    focus() { view.focus(); },
    destroy() { view.destroy(); },
  };
}
