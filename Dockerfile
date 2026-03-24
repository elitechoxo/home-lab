FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash sudo curl git nano python3 python3-pip tmux \
    openssh-server unzip wget ca-certificates \
    build-essential ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 2222" >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# Set root password
RUN echo "root:root" | chpasswd

# SSH Key setup
RUN mkdir -p /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO45Zk6dR7Pd/hR/QFo11k+avtEEvkim/9ymK4nTnBqG" >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz && \
    tar -xzf ngrok-v3-stable-linux-amd64.tgz -C /usr/local/bin && \
    rm ngrok-v3-stable-linux-amd64.tgz

# Keep-alive HTTP server
RUN printf '%s\n' \
    'from http.server import BaseHTTPRequestHandler, HTTPServer' \
    'class H(BaseHTTPRequestHandler):' \
    '    def do_GET(self):' \
    '        self.send_response(200)' \
    '        self.end_headers()' \
    '        self.wfile.write(b"ONLINE")' \
    '    def log_message(self, *a): pass' \
    'HTTPServer(("0.0.0.0",10000),H).serve_forever()' \
    > /server.py

# Start script
RUN printf '%s\n' \
    '#!/bin/sh' \
    'python3 /server.py &' \
    'ngrok config add-authtoken 2bmDkAveY0grVVDlgwVXiOP5ia2_3vyBFrEpUdZou7veySN6p' \
    'ngrok tcp --region ap 2222 >/dev/null 2>&1 &' \
    '/usr/sbin/sshd -D' \
    > /start && chmod +x /start

EXPOSE 10000 2222

CMD ["/start"]
