#!/usr/bin/env python3
"""Sinh icon app khách hàng (nền xanh #0B5D55, biểu tượng chứng chỉ + dấu tích).

Chạy: python3 tool/gen_customer_icon.py  (cần Pillow). Ghi:
  - android/app/src/customer/res/mipmap-*/ic_launcher.png
  - ios/Runner/Assets.xcassets/AppIcon-customer.appiconset/*
Thay bằng icon thương hiệu thật khi có (giữ đúng tên file/kích thước).
"""
import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRI = (11, 93, 85)
WHITE = (255, 255, 255)
AMBER = (240, 180, 60)


def master(size=1024, rounded=False):
    s = size
    img = Image.new("RGBA", (s, s), PRI + (255,))
    d = ImageDraw.Draw(img)
    # tờ chứng chỉ
    x0, y0, x1, y1 = s * 0.24, s * 0.20, s * 0.76, s * 0.80
    d.rounded_rectangle((x0, y0, x1, y1), radius=s * 0.05, fill=WHITE)
    # dòng chữ giả
    for i, w in enumerate((0.34, 0.28)):
        yy = s * (0.30 + i * 0.07)
        d.rounded_rectangle((s * 0.31, yy, s * 0.31 + s * w, yy + s * 0.025), radius=s * 0.012, fill=(200, 215, 212))
    # con dấu + dấu tích
    cx, cy, r = s * 0.5, s * 0.60, s * 0.115
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PRI)
    pts = [(cx - r * 0.5, cy + r * 0.02), (cx - r * 0.12, cy + r * 0.4), (cx + r * 0.52, cy - r * 0.34)]
    d.line(pts, fill=WHITE, width=int(s * 0.03), joint="curve")
    if rounded:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, s, s), radius=s * 0.22, fill=255)
        out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        return out
    return img


def save(img, path, px):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((px, px), Image.LANCZOS).save(path)


def main():
    m = master(1024)
    mr = master(1024, rounded=True)
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(mr, f"{ROOT}/android/app/src/customer/res/mipmap-{name}/ic_launcher.png", px)
    # iOS: ảnh vuông, không alpha (App Store từ chối ảnh có alpha)
    ios = f"{ROOT}/ios/Runner/Assets.xcassets/AppIcon-customer.appiconset"
    flat = m.convert("RGB")
    sizes = [
        (20, 1, "iphone"), (20, 2, "iphone"), (20, 3, "iphone"),
        (29, 1, "iphone"), (29, 2, "iphone"), (29, 3, "iphone"),
        (40, 2, "iphone"), (40, 3, "iphone"), (60, 2, "iphone"), (60, 3, "iphone"),
        (20, 1, "ipad"), (20, 2, "ipad"), (29, 1, "ipad"), (29, 2, "ipad"),
        (40, 1, "ipad"), (40, 2, "ipad"), (76, 1, "ipad"), (76, 2, "ipad"), (83.5, 2, "ipad"),
        (1024, 1, "ios-marketing"),
    ]
    images = []
    for pt, scale, idiom in sizes:
        px = int(round(pt * scale))
        fn = f"Icon-{pt}@{scale}x-{idiom}.png".replace(".5", "_5")
        save(flat, f"{ios}/{fn}", px)
        images.append({"size": f"{pt:g}x{pt:g}", "idiom": idiom, "filename": fn, "scale": f"{scale}x"})
    with open(f"{ios}/Contents.json", "w") as f:
        json.dump({"images": images, "info": {"version": 1, "author": "xcode"}}, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
