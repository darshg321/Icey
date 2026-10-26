---
title: Teaching gates to count
part: 1
blurb: Build an adder from gates, then build a bigger one out of copies of the first. Modules inside modules, and what + really costs.
---

Here's a question that sounds like it's from a different subject. How do you add two numbers using only AND, OR and XOR?

Go back to how you learned to add on paper. You work right to left, one column at a time. In each column you add two digits plus whatever got carried in from the column before, write down one digit, and carry the rest to the next column. Binary works the same way, but each column only ever holds 0 or 1, so it's a much smaller table to learn.

## One column

Add two bits, `a` and `b`, plus a carry in, `cin`. The total is somewhere from 0 to 3, which takes two bits to write: the sum bit for this column, and a carry for the next one.

| a | b | cin | total | carry out | sum |
|---|---|-----|-------|-----------|-----|
| 0 | 0 | 0 | 0 | 0 | 0 |
| 0 | 1 | 0 | 1 | 0 | 1 |
| 1 | 1 | 0 | 2 | 1 | 0 |
| 1 | 1 | 1 | 3 | 1 | 1 |
| … | | | | | |

Look at the sum column. It's 1 when the total is odd, so when an odd number of the three inputs are 1. You saw that in the last lesson: it's XOR. `sum = a ^ b ^ cin`.

Now the carry. It's 1 when the total is 2 or 3, meaning at least two of the three inputs are 1. You built that in lesson 2, for the three judges. It's the majority function.

That's a *full adder*. Two familiar circuits, side by side.

@exercise full-adder

## Four columns

One column adds one bit. To add two 4-bit numbers you need four columns, with the carry out of each one feeding the carry in of the next. You could copy and paste the logic four times with different bit numbers, but there's a better way. Turn the full adder into its own module, and *instantiate* it four times.

```verilog
module full_adder(input a, b, cin, output sum, cout);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module top(input [3:0] a, b, output [4:0] total);
  wire c1, c2, c3;
  full_adder fa0(.a(a[0]), .b(b[0]), .cin(1'b0), .sum(total[0]), .cout(c1));
  full_adder fa1(.a(a[1]), .b(b[1]), .cin(c1),   .sum(total[1]), .cout(c2));
  // ... and two more
endmodule
```

Each line in `top` places one physical copy of `full_adder` on the chip. `fa0` and `fa1` are names for those copies (instances), and `.a(a[0])` connects the instance's port `a` to the signal `a[0]` out here. These are called named port connections. Verilog also lets you connect ports by position, `full_adder fa0(a[0], b[0], ...)`, and you should avoid it. It works until somebody reorders the ports in the module, and then it silently connects everything to the wrong thing.

This is the real point of modules. In software you'd call a function four times; here you're stamping out four circuits, all running at once. There's no "calling" and no "returning", only copies.

@exercise ripple

The carry has to pass through every column in turn before the top bit's answer is right, like a ripple running along the adder. That's why this design is called a ripple-carry adder. For four bits that's quick. For 64 bits it's the longest path in the circuit, and lesson 19 is about exactly that kind of problem.

## Or just write +

Having built one by hand, you're now allowed to never do it again:

```verilog
assign total = a + b;
```

Yosys knows how to build adders. On the iCE40 it's better than knowing: each logic cell has a little piece of dedicated carry circuitry built into the silicon, so `+` turns into a fast carry chain instead of general-purpose gates. Your ripple adder can't use those, because Yosys can't tell that your hand-written gates happen to be an adder.

Watch the width, though. Two 4-bit numbers can add up to 30, which needs 5 bits. If `total` is 5 bits wide, Verilog widens `a` and `b` to 5 bits before adding and you get the carry. If you make `total` 4 bits wide, the top bit gets dropped and 9 + 9 comes out as 2. No warning, of course.

@exercise plus

Once it passes, open the Gates tab and compare the gate count with your ripple adder. Then click **build for Icey** on both and compare the number of logic cells used, which is a better measure. The chip view also shows you the carry chain as a column of blue cells.
