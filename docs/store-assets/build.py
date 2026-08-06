#!/usr/bin/env python3
"""스토어 스크린샷 8장 생성기 — slides.json + 캡처 PNG → 1080×1920 최종 이미지.

사용법:  python3 build.py [슬라이드번호 ...]   (번호 생략 시 캡처가 존재하는 슬라이드 전부)
캡처 파일(cap-*.png)이 없는 슬라이드는 건너뛴다. 실캡처로 갈아끼우면 다시 실행만 하면 됨.
"""
import json
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT = (HERE / "../../flutter_app/assets/fonts/PretendardVariable.ttf").resolve()

TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{
  font-family: 'Pretendard';
  src: url('file://{font}') format('truetype');
}}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: 1080px; height: 1920px; overflow: hidden; }}
body {{
  font-family: 'Pretendard', 'Apple SD Gothic Neo', sans-serif;
  background: linear-gradient(180deg, #F0F9FF 0%, #E0F2FE 52%, #BAE6FD 100%);
  position: relative;
}}
.blob {{ position: absolute; border-radius: 999px; filter: blur(2px); }}
.b1 {{ width: 420px; height: 420px; left: -140px; top: 430px; background: #0EA5E912; }}
.b2 {{ width: 300px; height: 300px; right: -90px; top: 240px; background: #0EA5E91A; }}
.brand {{
  position: absolute; top: 96px; left: 50%; transform: translateX(-50%);
  background: #FFFFFF; color: #0284C7; font-weight: 800; font-size: 30px;
  padding: 14px 34px; border-radius: 999px; letter-spacing: -0.5px;
  box-shadow: 0 8px 24px #0EA5E922;
}}
h1 {{
  position: absolute; top: 205px; width: 100%; text-align: center;
  font-size: 86px; font-weight: 900; color: #0F172A;
  line-height: 1.22; letter-spacing: -2.5px;
}}
h1 em {{ font-style: normal; color: #0284C7; }}
.sub {{
  position: absolute; top: 470px; width: 100%; text-align: center;
  font-size: 40px; font-weight: 600; color: #64748B; letter-spacing: -1px;
}}
.phone {{
  position: absolute; left: 50%; transform: translateX(-50%);
  top: 590px; width: 800px; height: 1420px;
  background: #FFFFFF; border-radius: 64px; padding: 18px;
  box-shadow: 0 40px 90px #0F172A2E;
}}
.phone .screen {{
  width: 100%; height: 100%; border-radius: 48px; overflow: hidden;
  background: #F7FAFD;
}}
.phone img {{ width: 100%; display: block; }}
.ph {{
  width: 100%; height: 100%; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 26px;
  background: linear-gradient(180deg, #F7FAFD 0%, #F0F9FF 100%);
}}
.ph .emoji {{ font-size: 130px; }}
.ph .label {{ font-size: 34px; font-weight: 700; color: #64748B; letter-spacing: -1px; }}
.ph .note {{ font-size: 24px; font-weight: 600; color: #94A3B8; }}
/* 브랜드 알약 없는 슬라이드(메인 등) — 여백 균형 위해 전체를 위로 당김 */
body.nobrand h1 {{ top: 150px; }}
body.nobrand .sub {{ top: 415px; }}
body.nobrand .phone {{ top: 535px; height: 1475px; }}
</style></head><body class="{body_class}">
<div class="blob b1"></div><div class="blob b2"></div>
{brand}
<h1>{headline}</h1>
<div class="sub">{sub}</div>
<div class="phone"><div class="screen">{screen}</div></div>
</body></html>"""


def build(slide):
    img = HERE / slide["img"]
    if img.exists():
        screen = f'<img src="file://{img.resolve()}">'
        note = ""
    else:
        # 캡처가 아직 없으면 자리표시 — cap 파일 넣고 재실행하면 실화면으로 교체됨.
        screen = (f'<div class="ph"><div class="emoji">{slide.get("emoji", "📱")}</div>'
                  f'<div class="label">{slide.get("label", "")}</div>'
                  f'<div class="note">캡처 교체 예정 · {slide["img"]}</div></div>')
        note = " (자리표시)"
    show_brand = slide.get("brand", True)
    html = HERE / f"_slide{slide['n']}.html"
    html.write_text(TEMPLATE.format(
        font=FONT, headline=slide["headline"], sub=slide["sub"], screen=screen,
        body_class="" if show_brand else "nobrand",
        brand='<div class="brand">하프트립</div>' if show_brand else ""))
    out = HERE / f"store-{slide['n']:02d}.png"
    subprocess.run([
        CHROME, "--headless=new", f"--screenshot={out}",
        "--window-size=1080,1920", "--hide-scrollbars", "--disable-gpu",
        f"file://{html}",
    ], check=True, capture_output=True)
    html.unlink()
    print(f"→ {out.name}{note}")


def main():
    slides = json.loads((HERE / "slides.json").read_text())
    wanted = {int(a) for a in sys.argv[1:]} if len(sys.argv) > 1 else None
    for slide in slides:
        if wanted is None or slide["n"] in wanted:
            build(slide)


if __name__ == "__main__":
    main()
