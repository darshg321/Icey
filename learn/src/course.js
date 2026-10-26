// Course structure. Each lesson is a folder in lessons/ with lesson.md
// (prose, frontmatter: title, part, blurb) and optionally exercises.js.
import { parseFrontmatter } from './markdown.js';

export const PARTS = [
  { n: 1, title: 'Logic in the browser', blurb: 'Write Verilog, watch it turn into gates, and run it on a board that lives in this page.' },
  { n: 2, title: 'Onto the real chip', blurb: 'Icey, Icestudio, and what the toolchain is actually doing to your code.' },
  { n: 3, title: 'Real tools, bigger builds', blurb: 'The command line, testbenches, serial, memory, video and timing. The stuff every project after this is made of.' },
  { n: 4, title: 'Things only hardware can do', blurb: 'Massive parallelism, a CPU of your own, an Apple I, and verifying a design the way chip companies do.' },
];

const mds = import.meta.glob('./lessons/*/lesson.md', { query: '?raw', import: 'default', eager: true });
const exs = import.meta.glob('./lessons/*/exercises.js', { eager: true });
const chipMds = import.meta.glob('./chip/*/lesson.md', { query: '?raw', import: 'default', eager: true });
const chipExs = import.meta.glob('./chip/*/exercises.js', { eager: true });

function load(mdFiles, exFiles, folder, idPrefix = '') {
  return Object.entries(mdFiles).map(([path, raw]) => {
    const dir = path.split('/')[2];
    const { meta, body } = parseFrontmatter(raw);
    const exMod = exFiles[`./${folder}/${dir}/exercises.js`];
    const exercises = exMod ? exMod.default : [];
    const id = idPrefix + dir.replace(/^\d+-/, '');
    return { dir, id, num: +dir.split('-')[0], title: meta.title, part: +meta.part, blurb: meta.blurb || '', body, exercises: exercises.map(e => ({ ...e, lessonTitle: meta.title })) };
  }).sort((a, b) => a.num - b.num);
}

export const LESSONS = load(mds, exs, 'lessons');

// The chip path: a short daily track (about 30 minutes a lesson) from no
// Verilog to a VGA demo ready for a shared-chip tapeout. Each lesson links to
// outside reading and leaves the writing to the learner.
export const CHIP = {
  title: 'Make a chip',
  blurb: 'One project, about 30 minutes a session: a VGA graphics chip, designed from your first line of Verilog to a layout ready for a real GF180 tapeout, tested on Icey along the way. Each session picks up your design where you left it.',
  phases: [
    { n: 1, title: 'The control panel', blurb: 'Your chip’s inputs and outputs, tried out on Icey’s LEDs, button and pins.' },
    { n: 2, title: 'The beam', blurb: 'Counters, modules and the timing a monitor expects.' },
    { n: 3, title: 'The picture', blurb: 'Colour from position, motion, and the controls.' },
    { n: 4, title: 'Tape-out', blurb: 'The Tiny Tapeout shape, verification, and shipping. Then your next chip.' },
  ],
  lessons: load(chipMds, chipExs, 'chip', 'chip-').map(l => ({ ...l, path: 'chip' })),
};

export const lessonById = id => LESSONS.find(l => l.id === id) || CHIP.lessons.find(l => l.id === id);
export const siblingsOf = l => (l.path === 'chip' ? CHIP.lessons : LESSONS);
