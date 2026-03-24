FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt update && apt install -y \
    bash sudo curl git nano python3 python3-pip screen \
    openssh-server unzip wget ca-certificates build-essential ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Setup SSH
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 2323" >> /etc/ssh/sshd_config

# Set root password
RUN echo "root:root" | chpasswd

# SSH Key setup
RUN mkdir -p /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO45Zk6dR7Pd/hR/QFo11k+avtEEvkim/9ymK4nTnBqG" >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# Install ngrok
RUN wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz && \
    tar -xzf ngrok-v3-stable-linux-amd64.tgz && \
    rm ngrok-v3-stable-linux-amd64.tgz && \
    chmod +x ngrok

# Tiny Python HTTP server
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
    './ngrok tcp --region ap 2323 >/dev/null 2>&1 &' \
    '/usr/sbin/sshd -D' \
    > /start && chmod +x /start

EXPOSE 10000 2323

CMD ["/start"]
