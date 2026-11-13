from pathlib import Path
from PIL import Image, ImageDraw

s = 3
im = Image.new('RGB', (512*s, 512*s), '#262b29')
d = ImageDraw.Draw(im)
def pts(points): return [(int(x*s), int(y*s)) for x,y in points]
def rect(values): return tuple(int(x*s) for x in values)

# A crock pot and a curled mound, rendered as a simple bold icon.
d.ellipse(rect((94, 371, 418, 405)), fill='#151816')
d.polygon(pts([(110,220),(402,220),(382,352),(353,376),(159,376),(130,352)]), fill='#555c52', outline='#111613', width=9*s)
d.rounded_rectangle(rect((96,205,416,234)), radius=8*s, fill='#9b8a65', outline='#111613', width=5*s)
d.polygon(pts([(145,202),(163,185),(211,174),(303,174),(351,185),(369,202)]), fill='#747964', outline='#111613', width=5*s)
d.ellipse(rect((235,160,277,184)), fill='#a5946c', outline='#111613', width=4*s)
for x in (178,256,334):
    d.line(pts([(x,155),(x-9,140),(x+6,126),(x-2,111)]), fill='#c9d0bf', width=7*s, joint='curve')
d.ellipse(rect((192,276,320,337)), fill='#795138', outline='#211b17', width=4*s)
d.ellipse(rect((211,255,301,311)), fill='#8c5d3d', outline='#211b17', width=4*s)
d.ellipse(rect((229,241,282,283)), fill='#a26d47', outline='#211b17', width=4*s)
d.line(pts([(244,257),(252,250),(262,252)]), fill='#d2a477', width=3*s)
im.resize((512,512), Image.Resampling.LANCZOS).save(Path(__file__).resolve().parents[1]/'preview.jpg','JPEG',quality=92,optimize=True)
