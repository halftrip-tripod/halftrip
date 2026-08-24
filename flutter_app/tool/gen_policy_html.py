#!/usr/bin/env python3
"""정책 웹페이지 생성기 — info_screens.dart의 약관·방침 원문을 호스팅용 HTML로 변환.

산출물: web/terms.html · web/privacy.html · web/account-deletion.html
→ flutter build web에 자동 포함되어 Vercel 배포 시 halftrip.vercel.app/<파일명>으로 서빙.
정책 원문(dart) 수정 후 이 스크립트를 다시 실행하면 됨:  python3 tool/gen_policy_html.py
"""
import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / 'lib/screens/info_screens.dart').read_text()
OUT = ROOT / 'web'

STYLE = '''<style>
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family:'Pretendard','Apple SD Gothic Neo','Malgun Gothic',sans-serif;
  background:#F7FAFD; color:#0F172A; line-height:1.75; }
.wrap { max-width:720px; margin:0 auto; padding:36px 22px 80px; }
.brand { font-size:15px; font-weight:800; color:#0284C7; margin-bottom:26px; }
h1 { font-size:23px; font-weight:900; letter-spacing:-.5px; margin-bottom:6px; }
.date { font-size:12.5px; font-weight:600; color:#94A3B8; margin-bottom:28px; }
h2 { font-size:15.5px; font-weight:800; color:#0284C7; margin:26px 0 6px; }
p { font-size:14px; color:#334155; }
.footer { margin-top:48px; padding-top:18px; border-top:1px solid #E2E8F0;
  font-size:12.5px; color:#94A3B8; font-weight:600; }
a { color:#0284C7; }
</style>'''


def extract(name):
    block = SRC.split(f'const {name} = [')[1].split('\n];')[0]
    return [
        (m.group(1), ''.join(re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(2))).replace('\\n', '\n'))
        for m in re.finditer(
            r"PolicySection\(\s*'((?:[^'\\]|\\.)*)',\s*((?:'(?:[^'\\]|\\.)*'\s*\n?\s*)+)\)", block)
    ]


def effective_date():
    dates = re.findall(r"effectiveDate: '([\d.]+)'", SRC)
    return dates[0] if dates else ''


def page(title, sections, extra_footer=''):
    body = '\n'.join(
        f'<h2>{html.escape(h)}</h2><p>{html.escape(b).replace(chr(10), "<br>")}</p>'
        for h, b in sections)
    return f'''<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — 하프트립</title>{STYLE}</head><body><div class="wrap">
<div class="brand">하프트립</div>
<h1>{title}</h1>
<div class="date">시행일: {effective_date()}</div>
{body}
<div class="footer">트리포드(Tripod) 팀 · 문의 rbgml4059@naver.com{extra_footer}</div>
</div></body></html>'''


DELETION_SECTIONS = [
    ('앱에서 삭제하기',
     '마이페이지 → 회원 탈퇴에서 즉시 계정과 데이터를 삭제할 수 있습니다.'),
    ('웹에서 삭제 요청하기 (앱을 지운 경우)',
     '아래 정보를 적어 rbgml4059@naver.com 으로 보내주세요. 요청일로부터 10일 이내 처리 결과를 회신합니다.\n'
     '· 가입에 사용한 소셜 계정 종류(카카오/네이버)와 이메일\n'
     '· "하프트립 계정 삭제 요청" 문구'),
    ('삭제되는 데이터',
     '계정 정보(로그인 식별자·이메일·거주지·닉네임·프로필), 여행 기록, 인증사진·영수증·숙박확인서, '
     '푸시 토큰, 알림·관심 지역이 삭제되며 복구할 수 없습니다.'),
    ('커뮤니티 게시물',
     '탈퇴 시 게시글·댓글은 작성자 정보가 비식별화("탈퇴한 사용자")된 상태로 남습니다. '
     '완전히 지우고 싶다면 탈퇴 전에 직접 삭제하거나, 위 이메일로 삭제를 함께 요청해 주세요.'),
    ('보관되는 데이터',
     '관련 법령상 보존 의무가 있는 기록이 있는 경우에 한해 해당 기간 동안 분리 보관 후 파기합니다.'),
]

terms = extract('_termsSections')
privacy = extract('_privacySections')
(OUT / 'terms.html').write_text(page('이용약관', terms))
(OUT / 'privacy.html').write_text(page(
    '개인정보처리방침', privacy,
    ' · <a href="account-deletion.html">계정 삭제 안내</a>'))
(OUT / 'account-deletion.html').write_text(page(
    '계정 및 데이터 삭제 안내', DELETION_SECTIONS,
    ' · <a href="privacy.html">개인정보처리방침</a>'))
print(f'생성 완료: terms({len(terms)}조) · privacy({len(privacy)}항) · account-deletion')
