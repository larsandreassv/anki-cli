#!/usr/bin/env python3
from pathlib import Path

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

TYPING_FRAME = 0.35
COMMAND_SETTLE = 0.45
READ_PAUSE = 1.8
CLEAR_PAUSE = 0.45

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


def clear_screen():
    global lines, cursor_row, cursor_col
    lines = ['']
    cursor_row = 0
    cursor_col = 0


def typing_stages(text):
    if len(text) <= 1:
        return [text]
    midpoint = max(1, len(text) // 2)
    return [text[:midpoint], text]


def draw_terminal(snapshot, *, show_cursor):
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

    if show_cursor:
        cursor_line = snapshot[-1] if snapshot else ''
        cursor_x = x0 + min(len(cursor_line), cols - 1) * char_width
        cursor_y = y0 + (min(len(snapshot), rows) - 1) * line_height
        draw.rectangle((cursor_x, cursor_y + line_height - 4, cursor_x + char_width, cursor_y + line_height - 2), fill=accent)
    return image

steps = []
pending_command = None

for record in records:
    content = record['content'].replace('\r\n', '\n').replace('\r', '')
    if content.startswith('\n$ '):
        if pending_command is not None:
            steps.append((pending_command, ''))
        pending_command = content.lstrip('\n').rstrip('\n')
    else:
        output_text = content.rstrip('\n')
        if pending_command is None:
            continue
        steps.append((pending_command, output_text))
        pending_command = None

if pending_command is not None:
    steps.append((pending_command, ''))

if not steps:
    raise SystemExit('no command steps recorded')

frames = []
frame_durations = []


def append_frame(duration, *, show_cursor):
    frames.append(draw_terminal(lines[-rows:], show_cursor=show_cursor))
    frame_durations.append(duration)


cover_command, cover_output = steps[0]
clear_screen()
feed(cover_command + '\n')
if cover_output:
    feed(cover_output + '\n')
append_frame(1.4, show_cursor=False)

for step_index, (command, output_text) in enumerate(steps):
    clear_screen()
    feed('$ ')
    append_frame(CLEAR_PAUSE, show_cursor=True)

    typed_prefix = ''
    for snapshot in typing_stages(command[2:]):
        feed(snapshot[len(typed_prefix):])
        typed_prefix = snapshot
        append_frame(TYPING_FRAME, show_cursor=True)

    append_frame(COMMAND_SETTLE, show_cursor=True)
    feed('\n')
    append_frame(0.3, show_cursor=False)

    output_lines = [line for line in output_text.split('\n') if line]
    if output_lines:
        feed('\n'.join(output_lines) + '\n')
    append_frame(READ_PAUSE, show_cursor=False)
    if step_index != len(steps) - 1:
        clear_screen()
        append_frame(CLEAR_PAUSE, show_cursor=False)

if frame_durations:
    frame_durations[-1] = 1.9

durations_ms = [max(1, int(duration * 1000)) for duration in frame_durations]
frames[0].save(
    output,
    save_all=True,
    append_images=frames[1:],
    duration=durations_ms,
    loop=0,
    optimize=False,
)
print(output)
