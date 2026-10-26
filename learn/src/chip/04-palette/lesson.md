---
title: A palette
part: 1
blurb: Choosing with `? :`, `if` and `case`. Pick a colour from a palette, with an override.
---

A picture is your chip choosing a colour for each pixel. Choosing is what `? :`, `if` and `case` are for. Today: a 4-colour palette picked by two switches, with reset overriding everything, and the preview from last session reused to show it.

```recall
Q: `colour` is `{r[1:0], g[1:0], b[1:0]}`. Write the expression that is 1 when any red bit is set.
A: `|colour[5:4]`
From: Session 3

Q: What does `{P2, P1}` make, and which one is the top bit?
A: A 2-bit vector; `P2`, the first one inside the braces, is the top bit.
From: Session 3

Q: Red while reset is held, otherwise blue if paused: if reset is held *and* pause is on, what colour?
A: Red. "Otherwise" means reset wins.
From: Session 2
```

## Learn

```resource
title: Conditional ternary operator
url: https://hdlbits.01xz.net/wiki/conditional
source: HDLBits
time: 3 min
do: Read about `cond ? a : b`. Solving it is optional.
```

```resource
title: Always blocks (combinational)
url: https://hdlbits.01xz.net/wiki/alwaysblock1
source: HDLBits
time: 4 min
do: `always @(*)` and why you assign to a `reg` inside it. Solve it.
```

```resource
title: Case statement
url: https://hdlbits.01xz.net/wiki/always_case
source: HDLBits
time: 5 min
do: Solve it.
```

```resource
title: Avoiding latches
url: https://hdlbits.01xz.net/wiki/always_nolatches
source: HDLBits
time: 3 min
do: Read only. The rule: in an `always @(*)`, every output gets a value on every path.
```

## Try it

```parsons
Same shape, different job. Order these lines so `width` is 200 while `big` is 1, and otherwise one of three sizes picked by `setting`.
---
always @(*) begin
  if (big)
    width = 8'd200;
  else
    case (setting)
      2'd0: width = 8'd10;
      2'd1: width = 8'd20;
      default: width = 8'd40;
    endcase
end
```

## Build

`{P2, P1}` picks a colour from your chip's palette:

| mode | colour | `rrggbb` |
|---|---|---|
| 0 | black | `000000` |
| 1 | red | `110000` |
| 2 | yellow | `111100` |
| 3 | white | `111111` |

While reset (SW2) is held, the colour is **blue** (`000011`) whatever the mode. Show the colour with the same preview as last session (any red bit lights red, and so on), and light LED1 when the colour is white.

@exercise c4-palette

```reflect
Your `case` has a `default`. What would go wrong without it if mode 3 had no line?
```

```sidequest
title: Priority encoder with casez
link: https://hdlbits.01xz.net/wiki/always_casez
time: 10 min
why: `casez` and don't-care bits: how to say "the first 1 from the right".

title: Find the bug in a case
link: https://hdlbits.01xz.net/wiki/bugs_case
time: 10 min
why: The classic `case` mistakes, in someone else's code.
```
