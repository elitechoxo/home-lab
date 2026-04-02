FROM ghcr.io/void-linux/void-glibc-busybox:latest

# Update and install packages
RUN xbps-install -Syu xbps && \
    xbps-install -Sy \
        bash sudo curl git nano python3 \
        openssh unzip ca-certificates \
        base-devel \
    && rm -rf /var/cache/xbps/*

# Install fxtun
RUN curl -fsSL https://fxtun.dev/install.sh | bash && \
    FXTUN_BIN=$(find /root /usr/local -name "fxtun" -type f 2>/dev/null | head -1) && \
    [ -n "$FXTUN_BIN" ] && ln -sf "$FXTUN_BIN" /usr/local/bin/fxtun || true

ENV PATH="/root/.fxtun/bin:/root/.local/bin:/usr/local/bin:$PATH"

# SSH setup
RUN ssh-keygen -A && \
    mkdir -p /run/sshd

RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 2200" >> /etc/ssh/sshd_config

RUN echo "root:root" | chpasswd

RUN mkdir -p /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHmat6s4EgTzfqWWGx5Takpyv8/D/ejnygc06QFW59hB" \
        >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

RUN cat > /web.py << 'EOF'
import http.server
import socketserver
import re

PORT = 3000

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()

        host = "Not found"
        port = ""
        raw_log = ""

        try:
            with open("/tmp/fxtun.log", "r") as f:
                raw_log = f.read()
                m = re.search(r"tcp://([^\s:]+):(\d+)", raw_log)
                if m:
                    host = m.group(1)
                    port = m.group(2)
                else:
                    m = re.search(r"([a-z0-9\-]+\.fxtun\.dev):(\d+)", raw_log)
                    if m:
                        host = m.group(1)
                        port = m.group(2)
        except Exception as e:
            raw_log = f"Log read error: {e}"

        if host != "Not found" and port:
            connect_cmd = f"ssh root@{host} -p {port}"
            endpoint_display = f"tcp://{host}:{port}"
        else:
            connect_cmd = "Waiting for tunnel..."
            endpoint_display = "Connecting... (refresh in a few seconds)"

        html = f"""<!DOCTYPE html>
<html>
<head>
  <title>SSH Tunnel</title>
  <meta http-equiv="refresh" content="5">
  <style>
    body {{ background: #0d1117; color: #c9d1d9; font-family: monospace; padding: 30px; max-width: 700px; margin: auto; }}
    h2 {{ color: #58a6ff; }}
    pre {{ background: #161b22; padding: 15px; border-radius: 8px; border: 1px solid #30363d; overflow-x: auto; color: #3fb950; }}
    .label {{ color: #8b949e; font-size: 0.85em; margin-top: 20px; margin-bottom: 4px; }}
    .status {{ color: #3fb950; }}
    details summary {{ cursor: pointer; color: #8b949e; margin-top: 20px; }}
  </style>
</head>
<body>
  <h2>🚀 SSH Tunnel</h2>
  <p class="status">● Live &nbsp;|&nbsp; Auto-refresh every 5s</p>
  <div class="label">ENDPOINT</div>
  <pre>{endpoint_display}</pre>
  <div class="label">CONNECT</div>
  <pre>{connect_cmd}</pre>
  <details>
    <summary>Raw tunnel log</summary>
    <pre>{raw_log[-2000:] if raw_log else "empty"}</pre>
  </details>
</body>
</html>"""

        self.wfile.write(html.encode())

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
EOF

RUN cat > /start.sh << 'EOF'
#!/bin/bash
export PATH="/root/.fxtun/bin:/root/.local/bin:/usr/local/bin:$PATH"

echo "[+] Starting SSH..."
/usr/sbin/sshd

echo "[+] fxtun path: $(which fxtun 2>/dev/null || echo NOT FOUND)"

echo "[+] Starting fxTunnel..."
fxtun tcp 2200 --token sk_fxtunnel_4e12d1fc552853f8f4607dd8084b558ab40f3de0d39caf39 > /tmp/fxtun.log 2>&1 &

sleep 3
echo "[+] Tunnel log so far:"
cat /tmp/fxtun.log

echo "[+] Starting Web UI on :3000..."
python3 /web.py
EOF

RUN chmod +x /start.sh

EXPOSE 3000 2200

CMD ["/start.sh"]
