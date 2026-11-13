from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

scale = 3
image = Image.new("RGB", (512 * scale, 512 * scale), "#765039")
draw = ImageDraw.Draw(image)
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 51 * scale)
draw.text((256 * scale, 276 * scale), "CAN COOK SHIT", font=font,
          fill="#f6e7c7", anchor="mm")

for x in (117, 256, 395):
    points = [(round((x + 9 * math.sin(i * math.pi / 15)) * scale),
               round((188 - i * 1.6) * scale)) for i in range(31)]
    draw.line(points, fill="#d5c397", width=6 * scale, joint="curve")

image.resize((512, 512), Image.Resampling.LANCZOS).save(
    Path(__file__).resolve().parents[1] / "preview.jpg", "JPEG", quality=92, optimize=True)
