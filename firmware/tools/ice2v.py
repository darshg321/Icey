#!/usr/bin/env python3
"""ice2v - turn an Icestudio project into Verilog + PCF without the GUI.

Handles projects built from Verilog code blocks and FPGA I/O pins (like the
examples in examples/icestudio); collection blocks are not supported.

    ice2v.py project.ice OUT_DIR      writes OUT_DIR/main.v and OUT_DIR/main.pcf
"""
import json
import os
import re
import sys


def convert(ice):
    g = ice['design']['graph']
    blocks = {b['id']: b for b in g['blocks']}
    code = {i: b for i, b in blocks.items() if b['type'] == 'basic.code'}
    ios = {i: b for i, b in blocks.items() if b['type'] in ('basic.input', 'basic.output')}
    other = [b['type'] for b in g['blocks']
             if b['type'] not in ('basic.code', 'basic.input', 'basic.output', 'basic.info')]
    if other:
        sys.exit(f'ice2v: unsupported block types: {sorted(set(other))}')

    def ident(s):
        return re.sub(r'\W', '_', s)

    names = {}
    for i, b in code.items():
        title = b['data']['code'].splitlines()[0].lstrip('/ ') if b['data']['code'] else ''
        names[i] = f'blk_{len(names)}_{ident(title)[:24]}'.rstrip('_')

    rng = lambda p: (p.get('range', '') + ' ') if p.get('range') else ''
    out = ['`default_nettype none\n']
    for i, b in code.items():
        ports = ([f"input {rng(p)}{p['name']}" for p in b['data']['ports']['in']] +
                 [f"output {rng(p)}{p['name']}" for p in b['data']['ports']['out']])
        out.append(f"module {names[i]} (\n  " + ',\n  '.join(ports) +
                   f"\n);\n{b['data']['code']}\nendmodule\n")

    top_ports, nets, pcf = [], [], []
    conns = {i: {} for i in code}
    for i, b in code.items():
        for p in b['data']['ports']['out']:
            net = f"w_{names[i]}_{p['name']}"
            nets.append(f"wire {rng(p)}{net};")
            conns[i][p['name']] = net
    for i, b in ios.items():
        d = b['data']
        rg = d.get('range', '')
        top_ports.append(f"{'input' if b['type'] == 'basic.input' else 'output'} {rg + ' ' if rg else ''}{d['name']}")
        for pin in d['pins']:
            pcf.append(f"set_io {d['name']}{'[' + pin['index'] + ']' if rg else ''} {pin['value']}")
    for w in g['wires']:
        s, t = w['source'], w['target']
        if s['block'] in ios:                      # input pin -> code block
            conns[t['block']][t['port']] = blocks[s['block']]['data']['name']
        elif t['block'] in ios:                    # code block -> output pin
            nets.append(f"assign {blocks[t['block']]['data']['name']} = w_{names[s['block']]}_{s['port']};")
        else:
            conns[t['block']][t['port']] = f"w_{names[s['block']]}_{s['port']}"
    inst = [f"{names[i]} u_{names[i]} (" + ', '.join(f'.{p}({c})' for p, c in conns[i].items()) + ');'
            for i in code]
    out.append("module main (\n  " + ',\n  '.join(top_ports) + "\n);\n" +
               '\n'.join(nets + inst) + "\nendmodule\n")
    return '\n'.join(out), '\n'.join(pcf) + '\n'


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    v, pcf = convert(json.load(open(sys.argv[1])))
    os.makedirs(sys.argv[2], exist_ok=True)
    open(os.path.join(sys.argv[2], 'main.v'), 'w').write(v)
    open(os.path.join(sys.argv[2], 'main.pcf'), 'w').write(pcf)
