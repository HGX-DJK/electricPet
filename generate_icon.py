import os
from PIL import Image, ImageDraw

def generate_pet_icon():
    os.makedirs("assets", exist_ok=True)
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 绘制外圈圆角暖橙色渐变/高对比度圆底
    margin = 8
    draw.ellipse([margin, margin, size - margin, size - margin], fill=(255, 170, 80, 255), outline=(220, 120, 30, 255), width=6)

    # 白色小猫脸
    cx, cy = size // 2, size // 2 + 10
    face_w, face_h = 160, 130
    draw.ellipse([cx - face_w // 2, cy - face_h // 2, cx + face_w // 2, cy + face_h // 2], fill=(255, 252, 245, 255))

    # 耳朵
    # 左耳
    draw.polygon([(cx - 70, cy - 40), (cx - 95, cy - 105), (cx - 20, cy - 60)], fill=(255, 170, 80, 255), outline=(220, 120, 30, 255))
    draw.polygon([(cx - 65, cy - 45), (cx - 85, cy - 95), (cx - 25, cy - 62)], fill=(255, 170, 180, 255))

    # 右耳
    draw.polygon([(cx + 70, cy - 40), (cx + 95, cy - 105), (cx + 20, cy - 60)], fill=(255, 170, 80, 255), outline=(220, 120, 30, 255))
    draw.polygon([(cx + 65, cy - 45), (cx + 85, cy - 95), (cx + 25, cy - 62)], fill=(255, 170, 180, 255))

    # 眼睛 (黑眼珠 + 白色高光)
    draw.ellipse([cx - 45, cy - 20, cx - 18, cy + 15], fill=(50, 35, 30, 255))
    draw.ellipse([cx - 40, cy - 16, cx - 26, cy - 2], fill=(255, 255, 255, 255))
    draw.ellipse([cx - 28, cy + 2, cx - 22, cy + 8], fill=(255, 255, 255, 255))

    draw.ellipse([cx + 18, cy - 20, cx + 45, cy + 15], fill=(50, 35, 30, 255))
    draw.ellipse([cx + 23, cy - 16, cx + 37, cy - 2], fill=(255, 255, 255, 255))
    draw.ellipse([cx + 35, cy + 2, cx + 41, cy + 8], fill=(255, 255, 255, 255))

    # 粉色腮红
    draw.ellipse([cx - 70, cy + 8, cx - 44, cy + 24], fill=(255, 140, 160, 170))
    draw.ellipse([cx + 44, cy + 8, cx + 70, cy + 24], fill=(255, 140, 160, 170))

    # 鼻子和嘴巴
    draw.polygon([(cx - 6, cy + 12), (cx + 6, cy + 12), (cx, cy + 18)], fill=(255, 150, 150, 255))
    draw.arc([cx - 16, cy + 14, cx, cy + 26], start=0, end=180, fill=(60, 40, 35, 255), width=3)
    draw.arc([cx, cy + 14, cx + 16, cy + 26], start=0, end=180, fill=(60, 40, 35, 255), width=3)

    # 保存 PNG 和多尺寸 Windows ICO
    png_path = os.path.join("assets", "app.png")
    ico_path = os.path.join("assets", "app.ico")
    img.save(png_path, "PNG")

    img.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print("Icon generated successfully:", png_path, ico_path)

if __name__ == "__main__":
    generate_pet_icon()
