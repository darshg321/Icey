# How the lessons are built, and why

The "Make a chip" path follows a handful of findings from learning research that
hold up across many studies. This is what each one is and where it shows up.

## Retrieval practice and spacing

Trying to recall something improves long-term memory more than reading it again,
even when the attempt fails. Spreading practice over days beats the same amount in
one block. Dunlosky et al.'s review of ten study techniques rated these two, and
only these two, as "high utility" ([Dunlosky et al. 2013][dunlosky];
[Roediger & Karpicke 2006][roediger]; [Cepeda et al. 2006][cepeda]).

- Every session from 2 on opens with a **warm-up**: a few questions answered from
  memory before revealing the answer. They come from the last session and from
  several sessions back, so each idea is recalled at growing intervals.
- Rating a question "not yet" puts it on a **review list** (kept in the browser);
  up to three come back in the next session's warm-up until you get them.
- Sessions are sized for one a day (~30 minutes) rather than one long sitting.

## Guided projects, not unguided discovery

Minimal guidance works badly for beginners ([Kirschner, Sweller & Clark 2006][kirschner]),
but project- and problem-based learning works well when it's heavily scaffolded
([Hmelo-Silver, Duncan & Chinn 2007][hmelo]).

- The path is **one project**: each session adds a piece of the same chip, and
  from session 6 on the workbench opens with **your own code from last time**
  (`carry` in an exercise), not a fresh starter.
- Each session states one concrete goal, links only the reading needed for it, and
  checks the result with tests that explain what's wrong.

## Worked examples, faded

Studying worked examples beats solving problems for novices; fading out the worked
steps gradually moves learners to solving on their own, and full worked examples
stop helping once learners know the material, the "expertise reversal" effect
([Renkl, Atkinson & Maier 2000][renkl]; [Kalyuga et al. 2003][kalyuga]).

- Early sessions give the port list and comments; later ones give less; by the end
  you write the testbench yourself from one worked example (session 12).
- Parsons problems in sessions 1 and 4 show an *analogous* worked example (same
  structure, different job) rather than the answer to the build.

## Parsons problems

Putting scrambled lines of code in order gives the same learning gains as writing
or fixing the same code, in less time ([Ericson, Margulieux & Rick 2017][ericson]).
Used for new syntax (module structure, `if`/`case` shape).

## Predict, then run (PRIMM)

Predict–Run–Investigate–Modify–Make ([Sentance, Waite & Kallia 2019][primm]) asks
learners to commit to a prediction before running code, then work from reading and
modifying towards writing.

- Every session has a **predict** block: you type a prediction before the answer
  is shown. Wrong predictions are the useful ones.
- The build step modifies your existing design before you make new parts.

## Self-explanation

Explaining material to yourself in your own words improves learning (rated
"moderate utility" by Dunlosky et al.). Each session ends with a one-question
**reflect** box; the answer stays in your browser.

## Interleaving and transfer

Mixing different kinds of problem helps learners tell them apart (also "moderate"
in Dunlosky et al.). The **Beyond the VGA** side quests mix in topics the chip
doesn't need (state machines, UART, debouncing, LFSRs, memory, formal
verification), mostly from the full course and HDLBits, so the Verilog you learn
isn't only VGA Verilog. Session 14 is about planning a different chip.

## Productive failure

Attempting a problem before instruction can improve conceptual understanding
([Sinha & Kapur 2021][kapur]), though the evidence is mostly from maths and
science. Used lightly: predictions come before the explanation, and the tests
include the failure cases learners usually hit first (missing resets, swapped pins).

[dunlosky]: https://www.psychologicalscience.org/news/releases/which-study-strategies-make-the-grade.html
[roediger]: https://doi.org/10.1111/j.1467-9280.2006.01693.x
[cepeda]: https://pubmed.ncbi.nlm.nih.gov/16719566/
[kirschner]: https://ntnu.no/wiki/download/attachments/8324914/sweller_kirschner_clark_reply_ep07.pdf
[hmelo]: https://classroom.eumetsat.int/mod/resource/view.php?id=4548
[renkl]: https://openlearning.mit.edu/mit-faculty/research-based-learning-findings/worked-and-faded-examples
[kalyuga]: https://en.wikipedia.org/wiki/Expertise_reversal_effect
[ericson]: https://hg.gatech.edu/node/603172
[primm]: https://eprints.gla.ac.uk/229013
[kapur]: https://www.weforum.org/stories/2021/09/students-who-productively-fail-learn-more/
