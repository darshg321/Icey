import './style.css';
import { PARTS, LESSONS, CHIP, lessonById, siblingsOf } from './course.js';
import { renderLesson } from './markdown.js';
import { Workbench } from './ui/workbench.js';
import { progress } from './progress.js';
import { warmUp, onToolchainProgress } from './engine/toolchain.js';
import { mountWidgets } from './widgets/index.js';
import './widgets/all.js';

const app = document.getElementById('app');
const BASE = import.meta.env.BASE_URL;
let workbench = null;
let selectById = () => {};
let reader = null; // { open(url, title) } for the current lesson page

function lessonDone(l) {
  return l.exercises.length ? l.exercises.every(e => progress.isDone(e.id)) : progress.isDone(`read:${l.id}`);
}

function header(current) {
  const where = current ? (current.path === 'chip' ? 'chip' : 'course') : '';
  return `<header class="top">
    <a href="#/" class="logo">Icey</a>
    <nav>
      <a href="#/chip" class="${where === 'chip' ? 'on' : ''}">Make a chip</a>
      <a href="#/course" class="${where === 'course' ? 'on' : ''}">Course</a>
    </nav>
    <span class="spacer"></span>
    <span class="tc-status"></span>
  </header>`;
}

const row = (l, label) => `
  <li class="${lessonDone(l) ? 'done' : ''}"><a href="#/l/${l.id}">
    <span class="n">${label}</span><span class="t"><b>${l.title}</b><span>${l.blurb}</span></span><span class="tick">✓</span>
  </a></li>`;

function home(focus) {
  document.title = 'Icey: learn hardware by building it';
  const chipDone = CHIP.lessons.filter(lessonDone).length;
  const courseDone = LESSONS.filter(lessonDone).length;
  const nextChip = CHIP.lessons.find(l => !lessonDone(l)) || CHIP.lessons[0];
  const nextCourse = LESSONS.find(l => !lessonDone(l)) || LESSONS[0];
  app.innerHTML = `${header()}
  <main class="home">
    <section class="hero">
      <div class="hero-text">
        <h1>Learn hardware by building it.</h1>
        <p>Verilog and FPGAs on <a href="https://github.com/darshg321/Icey">Icey</a>, an Uno-sized iCE40 board. The real toolchain runs in this page: Yosys turns your code into gates, a simulator runs those gates on a picture of the board, and nextpnr builds a bitstream for the real one.</p>
        <div class="paths">
          <a class="path" href="#/l/${nextChip.id}">
            <b>Make a chip</b>
            <span>One project: a VGA graphics chip, from your first line of Verilog to a layout ready for tapeout. ${CHIP.lessons.length} sessions of about 30 minutes.</span>
            <em>${chipDone ? `Continue: session ${nextChip.num} →` : 'Start →'}</em>
          </a>
          <a class="path" href="#/l/${nextCourse.id}">
            <b>The full course</b>
            <span>${LESSONS.length} lessons, from an LED to a CPU and an Apple I. Deeper and broader; the chip project links into it.</span>
            <em>${courseDone ? `Continue: lesson ${nextCourse.num} →` : 'Start →'}</em>
          </a>
        </div>
      </div>
      <img class="hero-img" src="${BASE}img/icey-photo.webp" alt="The Icey board from above">
    </section>

    <section class="track" id="chip">
      <h2>Make a chip <small>${chipDone ? `${chipDone} of ${CHIP.lessons.length} done` : ''}</small></h2>
      <p class="lead">${CHIP.blurb}</p>
      ${CHIP.phases.map(p => `
        <h3>${p.title}</h3>
        <p class="muted">${p.blurb}</p>
        <ol class="rows">${CHIP.lessons.filter(l => l.part === p.n).map(l => row(l, l.num)).join('')}</ol>`).join('')}
    </section>

    <section class="track" id="course">
      <h2>The full course <small>${courseDone ? `${courseDone} of ${LESSONS.length} done` : ''}</small></h2>
      ${PARTS.map(p => `
        <h3>${p.title}</h3>
        <p class="muted">${p.blurb}</p>
        <ol class="rows">${LESSONS.filter(l => l.part === p.n).map(l => row(l, l.num)).join('')}</ol>`).join('')}
    </section>
    <footer class="muted small">Icey is open hardware (OSHWA CA000078). Yosys and nextpnr in the browser come from the YoWASP project. <a href="#" class="reset-progress">Reset my progress</a></footer>
  </main>`;
  app.querySelector('.reset-progress').onclick = e => {
    e.preventDefault();
    if (e.target.dataset.armed) { progress.reset(); localStorage.removeItem('icey-review'); home(); } else { e.target.dataset.armed = 1; e.target.textContent = 'Click again to wipe progress and saved code'; }
  };
  if (focus) document.getElementById(focus)?.scrollIntoView();
  else window.scrollTo(0, 0);
}

// The right-hand side of a lesson: the workbench, and a reader that resources
// open in, on top of it.
function makeReader(side, hasWb) {
  const el = document.createElement('div');
  el.className = 'reader';
  el.hidden = hasWb;
  el.innerHTML = `
    <div class="reader-bar"><span class="reader-title">Reading</span><span class="spacer"></span>
      <a class="ext" target="_blank" rel="noopener">New tab ↗</a>
      ${hasWb ? '<button class="close">Back to the workbench</button>' : ''}</div>
    <div class="reader-body"><p class="reader-empty">Readings and exercises from other sites open here, next to the lesson.</p></div>`;
  side.append(el);
  el.querySelector('.close')?.addEventListener('click', () => { el.hidden = true; });
  return {
    open(url, title) {
      el.hidden = false;
      el.querySelector('.reader-title').textContent = title || url;
      el.querySelector('.ext').href = url;
      const body = el.querySelector('.reader-body');
      if (body.dataset.url !== url) {
        body.dataset.url = url;
        body.innerHTML = `<iframe src="${url}" title="${title || ''}" referrerpolicy="no-referrer"></iframe>`;
      }
    },
  };
}

window.addEventListener('icey:read', e => {
  const { url, title } = e.detail;
  if (reader && window.innerWidth > 1100) reader.open(url, title);
  else window.open(url, '_blank', 'noopener');
});

function lesson(id) {
  const l = lessonById(id);
  if (!l) return home();
  const chip = l.path === 'chip';
  document.title = `${l.title} · Icey`;
  const list = siblingsOf(l);
  const idx = list.indexOf(l);
  const prev = list[idx - 1], next = list[idx + 1];
  const hasEx = l.exercises.length > 0;
  const hasRes = /```(resource|sidequest)/.test(l.body);
  const side = hasEx || hasRes;
  const phase = chip ? CHIP.phases.find(p => p.n === l.part) : PARTS.find(p => p.n === l.part);
  app.innerHTML = `${header(l)}
  <main class="lesson ${side ? 'with-side' : ''}">
    <article class="prose">
      <div class="kicker">${chip ? `Session ${l.num} of ${list.length}` : `Lesson ${l.num}`} · ${phase?.title || ''}</div>
      <h1>${l.title}</h1>
      ${renderLesson(l.body)}
      <nav class="pager">
        ${prev ? `<a href="#/l/${prev.id}">← ${prev.title}</a>` : '<span></span>'}
        ${!hasEx ? `<button class="mark-read ${progress.isDone(`read:${l.id}`) ? 'on' : ''}">${progress.isDone(`read:${l.id}`) ? '✓ Done' : 'Mark as done'}</button>` : ''}
        ${next ? `<a href="#/l/${next.id}">${next.title} →</a>` : `<a href="#/${chip ? 'chip' : 'course'}">All ${chip ? 'sessions' : 'lessons'}</a>`}
      </nav>
    </article>
    ${side ? `<aside class="side">${hasEx ? '<div class="wb"></div>' : ''}</aside>` : ''}
  </main>`;
  const mark = app.querySelector('.mark-read');
  if (mark) mark.onclick = () => { progress.markDone(`read:${l.id}`); mark.textContent = '✓ Done'; mark.classList.add('on'); };

  reader = side ? makeReader(app.querySelector('.side'), hasEx) : null;
  mountWidgets(app.querySelector('.prose'));

  if (workbench && workbench.board) workbench.board.destroy();
  workbench = null;
  selectById = () => {};
  if (hasEx) {
    workbench = new Workbench(app.querySelector('.wb'));
    window.__wb = workbench; // handy for poking at it from the console
    workbench.onPass = ex => {
      refreshCards();
      const card = app.querySelector(`.ex-card[data-id="${ex.id}"]`);
      if (card) card.classList.add('just-done');
    };
    const cards = [];
    for (const slot of app.querySelectorAll('.ex-slot')) {
      const ex = l.exercises.find(e => e.id === slot.dataset.id);
      if (!ex) { slot.textContent = `(missing exercise ${slot.dataset.id})`; continue; }
      const card = document.createElement('div');
      card.className = 'ex-card';
      card.dataset.id = ex.id;
      card.innerHTML = `<div class="ex-top"><span class="ex-label">${chip ? 'Build' : ex.project ? 'Project' : 'Exercise'}</span><b>${ex.title}</b><span class="spacer"></span><span class="ex-done">✓ Done</span></div>
        <div class="ex-body">${renderLesson(ex.prompt || '')}</div>
        <button class="open">Open in the workbench →</button>`;
      card.querySelector('.open').onclick = () => select(ex);
      card.addEventListener('click', e => { if (e.target.tagName !== 'A') select(ex); });
      slot.replaceWith(card);
      cards.push(card);
    }
    let quietUntil = 0;   // don't let scrolling override a deliberate choice
    const select = (ex, fromScroll = false) => {
      if (!fromScroll) quietUntil = performance.now() + 1200;
      app.querySelector('.reader').hidden = true;
      if (workbench.ex === ex) return;
      cards.forEach(c => c.classList.toggle('active', c.dataset.id === ex.id));
      workbench.load(ex);
      history.replaceState(null, '', `#/l/${l.id}/${ex.id}`);
    };
    const refreshCards = () => cards.forEach(c => c.classList.toggle('done', progress.isDone(c.dataset.id)));
    selectById = exId => {
      const ex = l.exercises.find(e => e.id === exId);
      if (ex) { select(ex); app.querySelector(`.ex-card[data-id="${ex.id}"]`)?.scrollIntoView({ block: 'center' }); }
    };
    refreshCards();
    const want = location.hash.split('/')[3];
    select(l.exercises.find(e => e.id === want) || l.exercises.find(e => !progress.isDone(e.id)) || l.exercises[0]);
    // Scrolling the lesson brings the nearest exercise into the workbench.
    const io = new IntersectionObserver(entries => {
      for (const en of entries) {
        if (en.isIntersecting && en.intersectionRatio > 0.6) {
          const ex = l.exercises.find(e => e.id === en.target.dataset.id);
          if (ex && workbench.ex !== ex && performance.now() > quietUntil && !workbench.root.contains(document.activeElement)) select(ex, true);
        }
      }
    }, { threshold: [0.6] });
    cards.forEach(c => io.observe(c));
  }
  if (!location.hash.split('/')[3]) window.scrollTo(0, 0);
}

function route() {
  const parts = location.hash.replace(/^#\/?/, '').split('/');
  if (parts[0] === 'l' && parts[1]) {
    if (app.dataset.lesson === parts[1]) { if (parts[2]) selectById(parts[2]); return; }
    app.dataset.lesson = parts[1];
    lesson(parts[1]);
  } else {
    app.dataset.lesson = '';
    reader = null;
    home(parts[0] === 'chip' || parts[0] === 'course' ? parts[0] : null);
  }
}

onToolchainProgress(p => {
  const el = app.querySelector('.tc-status');
  if (el) el.innerHTML = p && p.total ? `<span class="spin"></span> ${p.stage} ${Math.round(100 * p.done / p.total)}%` : '';
});

window.addEventListener('hashchange', route);
route();
setTimeout(warmUp, 1500);
