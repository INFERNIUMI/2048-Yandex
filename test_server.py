#!/usr/bin/env python3
"""
Локальный сервер для тестирования игры в браузере.
Использование: python test_server.py
"""

import http.server
import socketserver
import os

PORT = 8000

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # CORS headers для тестирования
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

os.chdir(os.path.dirname(os.path.abspath(__file__)))

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"🎮 Локальный тестовый сервер запущен:")
    print(f"   http://localhost:{PORT}/test_local.html")
    print(f"\n📝 Для тестирования:")
    print(f"   1. Экспортируй игру в корень проекта (index.html)")
    print(f"   2. Открой http://localhost:{PORT}/test_local.html")
    print(f"\nНажми Ctrl+C для остановки\n")
    httpd.serve_forever()
