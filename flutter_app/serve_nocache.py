"""로컬 리뷰용 정적 서버 — 브라우저가 항상 최신 빌드를 받도록 캐시를 끈다."""
import http.server, functools, sys

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def log_message(self, *args):
        pass

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8643
handler = functools.partial(NoCacheHandler, directory='build/web')
http.server.ThreadingHTTPServer(('', port), handler).serve_forever()
