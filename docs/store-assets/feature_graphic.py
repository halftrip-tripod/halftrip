#!/usr/bin/env python3
"""feature graphic(1024×500) 생성 — 스토어 상단 배너 '포스터'."""
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT = (HERE / "../../flutter_app/assets/fonts/PretendardVariable.ttf").resolve()
CAP = (HERE / "cap-home.png").resolve()

HTML = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family:'Pretendard'; src:url('file://{FONT}') format('truetype'); }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:1024px; height:500px; overflow:hidden; }}
body {{
  font-family:'Pretendard','Apple SD Gothic Neo',sans-serif; position:relative;
  background:linear-gradient(115deg,#F0F9FF 0%,#DFF2FE 55%,#B8E4FB 100%);
}}
.blob {{ position:absolute; border-radius:999px; }}
.b1 {{ width:340px; height:340px; right:220px; top:-160px; background:#0EA5E914; }}
.b2 {{ width:220px; height:220px; left:-70px; bottom:-90px; background:#0EA5E91C; }}
.copy {{ position:absolute; left:76px; top:50%; transform:translateY(-50%); }}
.brand {{
  display:inline-block; background:#FFFFFF; color:#0284C7; font-weight:800;
  font-size:21px; padding:9px 22px; border-radius:999px; letter-spacing:-.5px;
  box-shadow:0 6px 18px #0EA5E922; margin-bottom:26px;
}}
h1 {{ font-size:56px; font-weight:900; color:#0F172A; line-height:1.24; letter-spacing:-2px; }}
h1 em {{ font-style:normal; color:#0284C7; }}
.sub {{ margin-top:20px; font-size:25px; font-weight:600; color:#64748B; letter-spacing:-.5px; }}
.phone {{
  position:absolute; right:88px; top:64px; width:300px;
  background:#FFFFFF; border-radius:34px; padding:9px;
  box-shadow:0 26px 60px #0F172A30; transform:rotate(4deg);
}}
.phone .screen {{ border-radius:26px; overflow:hidden; background:#F7FAFD; }}
.phone img {{ width:100%; display:block; }}
</style></head><body>
<div class="blob b1"></div><div class="blob b2"></div>
<div class="copy">
  <h1>복잡한 반값여행,<br><em>하프트립 하나로</em></h1>
  <div class="sub">정보 확인부터 인증·증빙·정산 관리까지</div>
</div>
<div class="phone"><div class="screen"><img src="file://{CAP}"></div></div>
</body></html>"""

html = HERE / "_fg.html"
html.write_text(HTML)
out = HERE / "feature-graphic.png"
subprocess.run([CHROME, "--headless=new", f"--screenshot={out}",
                "--window-size=1024,500", "--hide-scrollbars", "--disable-gpu",
                f"file://{html}"], check=True, capture_output=True)
html.unlink()
print(f"→ {out.name}")
