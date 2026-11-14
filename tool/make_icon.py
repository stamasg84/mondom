# Generates the Android launcher icons and the 512px store icon from the artwork.
# Usage: python tool/make_icon.py tool/icon/mondomikon.jpg <out_dir>  (needs Pillow + numpy)
# Then copy <out_dir>/res/* into android/app/src/main/res/ and play_icon_512.png into fastlane/.
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, sys, os
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
# rounded square bounds (measured), slightly taller than wide -> normalise to square
N = 1024
full = im.crop((415, 77, 995, 696)).resize((N, N), Image.LANCZOS)
fa = np.asarray(full).astype(float)

def rr_mask(size, inset, radius, blur=0):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((inset, inset, size-1-inset, size-1-inset), radius, fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur)) if blur else m

# Face colour per row, sampled just inside the glowing border on both sides
rows = np.array([np.median(np.concatenate([fa[y, 32:44], fa[y, N-44:N-32]]), axis=0) for y in range(N)])
# smooth, and keep the corner regions from skewing it
yy = np.arange(N); good = (yy > 180) & (yy < N-180)
coef = [np.polyfit(yy[good], rows[good, c], 2) for c in range(3)]
grad = np.stack([np.polyval(coef[c], yy) for c in range(3)], 1)

def background(size):
    ys = np.linspace(-0.25*N, 1.25*N, size)
    g = np.stack([np.polyval(coef[c], np.clip(ys, 0.18*N, 0.82*N)) for c in range(3)], 1)
    return Image.fromarray(np.clip(np.repeat(g[:, None, :], size, 1), 0, 255).astype('uint8'))

# Foreground: the face without its glowing rim, edges feathered into the background
fg = full.copy()
fg.putalpha(rr_mask(N, 46, 150, blur=18))

def compose(size, art_frac):
    bg = background(size).convert('RGBA')
    s = int(round(size*art_frac))
    f = fg.resize((s, s), Image.LANCZOS)
    bg.alpha_composite(f, ((size-s)//2, (size-s)//2))
    return bg

os.makedirs(out, exist_ok=True)
res = os.path.join(out, 'res')
dens = {'mdpi':1, 'hdpi':1.5, 'xhdpi':2, 'xxhdpi':3, 'xxxhdpi':4}
for d, k in dens.items():
    p = os.path.join(res, f'mipmap-{d}'); os.makedirs(p, exist_ok=True)
    a = int(108*k)  # adaptive layers, 108dp
    background(a).save(os.path.join(p, 'ic_launcher_background.png'))
    fgl = Image.new('RGBA', (a, a), (0,0,0,0)); s = int(round(a*0.66))
    fgl.alpha_composite(fg.resize((s, s), Image.LANCZOS), ((a-s)//2, (a-s)//2))
    fgl.save(os.path.join(p, 'ic_launcher_foreground.png'))
    # legacy icon (API 24-25): the original rounded square on transparent
    l = int(48*k)
    leg = full.copy(); leg.putalpha(rr_mask(N, 10, 170, blur=2))
    leg.resize((l, l), Image.LANCZOS).save(os.path.join(p, 'ic_launcher.png'))
# Play Store icon (512, full square, Play applies the mask)
compose(512, 1.0).convert('RGB').save(os.path.join(out, 'play_icon_512.png'))
# previews: adaptive with circle and squircle masks
prev = Image.new('RGB', (900, 330), (40, 40, 40))
for i, shape in enumerate(['circle', 'squircle', 'play']):
    if shape == 'play':
        t = Image.open(os.path.join(out, 'play_icon_512.png')).resize((288, 288)).convert('RGBA')
        m = rr_mask(288, 0, 58)
    else:
        a = compose(432, 0.66).resize((432, 432))
        t = a.crop((72, 72, 360, 360))  # visible 72dp of 108
        m = Image.new('L', (288, 288), 0); dr = ImageDraw.Draw(m)
        (dr.ellipse((0, 0, 287, 287), fill=255) if shape == 'circle' else dr.rounded_rectangle((0, 0, 287, 287), 90, fill=255))
    prev.paste(t, (20+i*295, 20), m)
prev.save(os.path.join(out, 'preview.png'))
