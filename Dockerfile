FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Update + install base deps
RUN apt update && apt install -y \
    bash sudo curl git nano tmux \
    openssh-server unzip wget ca-certificates build-essential ffmpeg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.13
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt update && apt install -y \
    python3.13 python3.13-dev \
    && ln -sf /usr/bin/python3.13 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.13 /usr/bin/python



# Setup SSH
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 2222" >> /etc/ssh/sshd_config

# Set root password
RUN echo "root:root" | chpasswd

# SSH Key
RUN mkdir -p /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO45Zk6dR7Pd/hR/QFo11k+avtEEvkim/9ymK4nTnBqG" >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# Install ngrok
RUN wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz && \
    tar -xzf ngrok-v3-stable-linux-amd64.tgz && \
    rm ngrok-v3-stable-linux-amd64.tgz && \
    chmod +x ngrok

# Tiny Python server
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
    '#!/bin/bash' \
    'python3 /server.py &' \
    './ngrok config add-authtoken 2bmDkAveY0grVVDlgwVXiOP5ia2_3vyBFrEpUdZou7veySL6p' \
    './ngrok tcp --region ap 2222 >/dev/null 2>&1 &' \
    '/usr/sbin/sshd -D' \
    > /start && chmod +x /start

EXPOSE 10000 2222

CMD ["/start"]
