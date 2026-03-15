#!/usr/bin/env python3
import html
from pathlib import Path

import imageio.v2 as imageio
import yaml
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('/home/larsandreas/repos/anki-cli')
recording = ROOT / 'assets' / 'terminalizer' / 'anki-demo.yml'
output = ROOT / 'assets' / 'anki-demo.gif'
font_path = Path('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf')

data = yaml.safe_load(recording.read_text())
config = data['config']
records = data['records']
cols = int(config['cols'])
rows = int(config['rows'])
font_size = int(config['fontSize'])
line_height = int(font_size * 1.5)
font = ImageFont.truetype(str(font_path), font_size)
char_width = int(ImageDraw.Draw(Image.new('RGB', (1, 1))).textlength('M', font=font))
term_w = cols * char_width + 32
term_h = rows * line_height + 32
img_w = term_w + 40
img_h = term_h + 60

bg = config['theme']['background']
fg = config['theme']['foreground']
frame_bg = '#0b1220'
header_bg = '#1f2937'
header_fg = '#d1d5db'
prompt_fg = config['theme']['green']
cmd_fg = '#ffffff'
accent = config['theme']['blue']

lines = ['']
cursor_row = 0
cursor_col = 0


def ensure_cursor_row():
    global lines, cursor_row
    while cursor_row >= len(lines):
        lines.append('')
    while len(lines) > rows:
        lines.pop(0)
        cursor_row -= 1


def put_char(ch):
    global cursor_col, cursor_row
    ensure_cursor_row()
    line = lines[cursor_row]
    if cursor_col > len(line):
        line += ' ' * (cursor_col - len(line))
    if cursor_col == len(line):
        line += ch
    else:
        line = line[:cursor_col] + ch + line[cursor_col + 1:]
    lines[cursor_row] = line[:cols]
    cursor_col += 1
    if cursor_col >= cols:
        cursor_col = 0
        cursor_row += 1
        ensure_cursor_row()


def feed(text):
    global cursor_col, cursor_row
    text = text.replace('\r\n', '\n').replace('\r', '')
    for ch in text:
        if ch == '\n':
            cursor_row += 1
            cursor_col = 0
            ensure_cursor_row()
        elif ch == '\t':
            for _ in range(4):
                put_char(' ')
        elif ch >= ' ':
            put_char(ch)


def draw_terminal(snapshot):
    image = Image.new('RGB', (img_w, img_h), frame_bg)
    draw = ImageDraw.Draw(image)
    outer = (20, 20, img_w - 20, img_h - 20)
    draw.rounded_rectangle(outer, radius=16, fill=bg)
    draw.rounded_rectangle((20, 20, img_w - 20, 54), radius=16, fill=header_bg)
    draw.rectangle((20, 38, img_w - 20, 54), fill=header_bg)
    for i, color in enumerate(('#fb7185', '#fbbf24', '#34d399')):
        cx = 42 + i * 20
        draw.ellipse((cx - 6, 32 - 6, cx + 6, 32 + 6), fill=color)
    title = 'anki demo'
    tw = draw.textlength(title, font=font)
    draw.text(((img_w - tw) / 2, 24), title, fill=header_fg, font=font)

    x0 = 36
    y0 = 68
    for i, line in enumerate(snapshot[-rows:]):
        y = y0 + i * line_height
        if line.startswith('$ '):
            draw.text((x0, y), '$', fill=prompt_fg, font=font)
            draw.text((x0 + char_width * 2, y), line[2:], fill=cmd_fg, font=font)
        else:
            draw.text((x0, y), line, fill=fg, font=font)

    # Cursor on final non-empty line for a terminal feel.
    cursor_line = snapshot[-1] if snapshot else ''
    cursor_x = x0 + min(len(cursor_line), cols - 1) * char_width
    cursor_y = y0 + (min(len(snapshot), rows) - 1) * line_height
    draw.rectangle((cursor_x, cursor_y + line_height - 4, cursor_x + char_width, cursor_y + line_height - 2), fill=accent)
    return image

frames = []
durations = []
for record in records:
    feed(record['content'])
    snapshot = lines[-rows:]
    frames.append(draw_terminal(snapshot))
    durations.append(max(160, min(int(record['delay']), 1100)))

if frames:
    durations[-1] = 1400

imageio.mimsave(output, frames, duration=[d / 1000 for d in durations], loop=0)
print(output)
