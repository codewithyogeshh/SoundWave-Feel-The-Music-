import math
import os
from PIL import Image, ImageDraw, ImageFilter

def create_soundwave_icon(size=512):
    # High resolution canvas
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size / 2
    radius = size * 0.46

    # 1. Base Squircle / Rounded Backdrop
    # Draw soft glowing outer aura
    for i in range(15, 0, -2):
        alpha = int(14 * (1 - i / 15))
        glow_r = radius + i * 3
        draw.ellipse(
            [center - glow_r, center - glow_r, center + glow_r, center + glow_r],
            fill=(133, 87, 246, alpha)
        )

    # 2. Main Dark Disc with Radial Gradient
    disc = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    disc_draw = ImageDraw.Draw(disc)
    
    # Gradient rings
    steps = 100
    for s in range(steps):
        r = radius * (1.0 - s / steps)
        # Gradient from deep royal navy (0x10, 0x17, 0x35) to midnight obsidian (0x07, 0x0A, 0x1A)
        factor = s / steps
        r_val = int(16 * (1 - factor) + 7 * factor)
        g_val = int(23 * (1 - factor) + 10 * factor)
        b_val = int(53 * (1 - factor) + 26 * factor)
        disc_draw.ellipse(
            [center - r, center - r, center + r, center + r],
            fill=(r_val, g_val, b_val, 255)
        )

    # Metallic / Neon Rim
    for w in range(3):
        rim_r = radius - w
        alpha = int(220 - w * 60)
        disc_draw.ellipse(
            [center - rim_r, center - rim_r, center + rim_r, center + rim_r],
            outline=(164, 92, 255, alpha),
            width=2
        )

    # Inner subtle vinyl concentric grooves
    for groove in [0.78, 0.64, 0.50, 0.36]:
        gr = radius * groove
        disc_draw.ellipse(
            [center - gr, center - gr, center + gr, center + gr],
            outline=(255, 255, 255, 12),
            width=1
        )

    img = Image.alpha_composite(img, disc)

    # 3. Dynamic Center Neon Equalizer Wave
    wave_overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wave_draw = ImageDraw.Draw(wave_overlay)

    # Dynamic soundwave bars (centered)
    bars = [
        (0.26, 0.35, (77, 158, 255)),   # Cyan/Neon Blue
        (0.33, 0.55, (100, 140, 255)),
        (0.40, 0.78, (133, 87, 246)),   # Violet
        (0.47, 0.98, (164, 92, 255)),   # Purple
        (0.54, 0.85, (210, 80, 245)),
        (0.61, 0.62, (230, 107, 239)),  # Magenta
        (0.68, 0.42, (255, 82, 154)),   # Hot Pink
        (0.75, 0.28, (255, 110, 180)),
    ]

    bar_width = size * 0.048
    bar_radius = bar_width / 2

    # Draw glow underneath bars
    for x_pct, height_pct, color in bars:
        bx = size * x_pct
        bh = size * 0.42 * height_pct
        y_top = center - bh / 2
        y_bot = center + bh / 2
        
        # Soft bloom
        wave_draw.rounded_rectangle(
            [bx - bar_width/2 - 6, y_top - 6, bx + bar_width/2 + 6, y_bot + 6],
            radius=bar_radius + 4,
            fill=(color[0], color[1], color[2], 80)
        )

    # Blur glow layer
    wave_glow = wave_overlay.filter(ImageFilter.GaussianBlur(8))
    img = Image.alpha_composite(img, wave_glow)

    # Draw sharp foreground bars
    sharp_bars = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sharp_draw = ImageDraw.Draw(sharp_bars)

    for x_pct, height_pct, color in bars:
        bx = size * x_pct
        bh = size * 0.42 * height_pct
        y_top = center - bh / 2
        y_bot = center + bh / 2

        sharp_draw.rounded_rectangle(
            [bx - bar_width/2, y_top, bx + bar_width/2, y_bot],
            radius=bar_radius,
            fill=(color[0], color[1], color[2], 255)
        )
        # Highlight gloss tip
        sharp_draw.ellipse(
            [bx - bar_width*0.35, y_top + 2, bx + bar_width*0.35, y_top + bar_width*0.7],
            fill=(255, 255, 255, 200)
        )

    img = Image.alpha_composite(img, sharp_bars)

    # 4. Floating Neon Music Note Emblem
    note_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    note_draw = ImageDraw.Draw(note_img)

    # Double eighth-note floating on top
    nx = size * 0.52
    ny = size * 0.42
    
    # Note stems & beam
    stem_w = int(size * 0.026)
    beam_h = int(size * 0.04)

    # Left head
    note_draw.ellipse([nx - size*0.14, ny + size*0.06, nx - size*0.04, ny + size*0.14], fill=(255, 255, 255, 240))
    # Right head
    note_draw.ellipse([nx + size*0.04, ny + size*0.02, nx + size*0.14, ny + size*0.10], fill=(255, 255, 255, 240))
    # Left stem
    note_draw.rectangle([nx - size*0.06, ny - size*0.12, nx - size*0.06 + stem_w, ny + size*0.10], fill=(255, 255, 255, 240))
    # Right stem
    note_draw.rectangle([nx + size*0.12, ny - size*0.16, nx + size*0.12 + stem_w, ny + size*0.06], fill=(255, 255, 255, 240))
    # Beam
    beam_pts = [
        (nx - size*0.06, ny - size*0.12),
        (nx + size*0.12 + stem_w, ny - size*0.16),
        (nx + size*0.12 + stem_w, ny - size*0.16 + beam_h),
        (nx - size*0.06, ny - size*0.12 + beam_h)
    ]
    note_draw.polygon(beam_pts, fill=(255, 255, 255, 245))

    note_glow = note_img.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img, note_glow)
    img = Image.alpha_composite(img, note_img)

    return img

def export_all():
    base_icon = create_soundwave_icon(512)
    
    # Target mipmap folders
    res_dir = r"E:\code-decor\workspace\SoundWave\android\app\src\main\res"
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, px in sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        resized = base_icon.resize((px, px), Image.Resampling.LANCZOS)
        
        # Save both square and round icons
        out_square = os.path.join(folder_path, "ic_launcher.png")
        out_round = os.path.join(folder_path, "ic_launcher_round.png")
        
        resized.save(out_square, "PNG")
        resized.save(out_round, "PNG")
        print(f"Saved {folder}: {px}x{px}")

    # Also save a 512x512 master in assets and artifacts
    master_path = r"E:\code-decor\workspace\SoundWave\assets\icon\app_icon.png"
    os.makedirs(os.path.dirname(master_path), exist_ok=True)
    base_icon.save(master_path, "PNG")

    artifact_path = r"C:\Users\DELL\.gemini\antigravity\brain\e6fbbdcc-0bb8-4191-a002-359ee4fa2678\app_icon_preview.png"
    base_icon.save(artifact_path, "PNG")
    print("Master icons generated successfully!")

if __name__ == "__main__":
    export_all()

