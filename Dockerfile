FROM archlinux:latest

# Update system and install essential packages
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    sudo \
    curl \
    git \
    nano \
    python \
    python-pip \
    screen \
    openssh \
    unzip \
    wget \
    ca-certificates \
    base-devel \
    ffmpeg \
    && pacman -Scc --noconfirm

# Install Deno
RUN curl -fsSL https://deno.land/install.sh | sh
ENV PATH="/root/.deno/bin:${PATH}"

# Generate SSH host keys
RUN ssh-keygen -A

# Configure SSH
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 2323" >> /etc/ssh/sshd_config

# Set root password
RUN echo "root:root" | chpasswd

# Add SSH key
RUN mkdir -p /root/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO45Zk6dR7Pd/hR/QFo11k+avtEEvkim/9ymK4nTnBqG" >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh

# Download and configure ngrok with auth token
RUN wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz && \
    tar xvzf ngrok.tgz && \
    rm ngrok.tgz && \
    chmod +x ngrok

# Create a simple Python HTTP server script
RUN echo '#!/usr/bin/env python3' > /python_server.py && \
    echo 'from http.server import HTTPServer, BaseHTTPRequestHandler' >> /python_server.py && \
    echo 'import json' >> /python_server.py && \
    echo 'import time' >> /python_server.py && \
    echo 'import socket' >> /python_server.py && \
    echo 'import os' >> /python_server.py && \
    echo '' >> /python_server.py && \
    echo 'class HealthHandler(BaseHTTPRequestHandler):' >> /python_server.py && \
    echo '    def do_GET(self):' >> /python_server.py && \
    echo '        if self.path == "/":' >> /python_server.py && \
    echo '            self.send_response(200)' >> /python_server.py && \
    echo '            self.send_header("Content-type", "text/html")' >> /python_server.py && \
    echo '            self.end_headers()' >> /python_server.py && \
    echo '            self.wfile.write(b"""' >> /python_server.py && \
    echo '<html><head><title>Render Bypass Server</title></head>' >> /python_server.py && \
    echo '<body style="font-family: Arial; text-align: center; margin-top: 50px;">' >> /python_server.py && \
    echo '<h1>🚀 Render Bypass Server Running</h1>' >> /python_server.py && \
    echo '<p>This server is keeping your service alive on Render!</p>' >> /python_server.py && \
    echo '<p>SSH, Deno, and FFmpeg are also available.</p>' >> /python_server.py && \
    echo '<hr>' >> /python_server.py && \
    echo '<h3>Server Info:</h3>' >> /python_server.py && \
    echo f'<p>Hostname: {socket.gethostname()}</p>' >> /python_server.py && \
    echo f'<p>Time: {time.strftime("%Y-%m-%d %H:%M:%S")}</p>' >> /python_server.py && \
    echo '</body></html>' >> /python_server.py && \
    echo '"""' >> /python_server.py && \
    echo '        elif self.path == "/health":' >> /python_server.py && \
    echo '            self.send_response(200)' >> /python_server.py && \
    echo '            self.send_header("Content-type", "application/json")' >> /python_server.py && \
    echo '            self.end_headers()' >> /python_server.py && \
    echo '            health_data = {' >> /python_server.py && \
    echo '                "status": "healthy",' >> /python_server.py && \
    echo '                "timestamp": time.time(),' >> /python_server.py && \
    echo '                "services": {' >> /python_server.py && \
    echo '                    "ssh": "available on ports 22, 2222, 2323",' >> /python_server.py && \
    echo '                    "deno": "installed",' >> /python_server.py && \
    echo '                    "ffmpeg": "installed",' >> /python_server.py && \
    echo '                    "ngrok": "configured"' >> /python_server.py && \
    echo '                }' >> /python_server.py && \
    echo '            }' >> /python_server.py && \
    echo '            self.wfile.write(json.dumps(health_data).encode())' >> /python_server.py && \
    echo '        else:' >> /python_server.py && \
    echo '            self.send_response(404)' >> /python_server.py && \
    echo '            self.end_headers()' >> /python_server.py && \
    echo '            self.wfile.write(b"404 Not Found")' >> /python_server.py && \
    echo '' >> /python_server.py && \
    echo '    def log_message(self, format, *args):' >> /python_server.py && \
    echo '        # Suppress log messages to keep console clean' >> /python_server.py && \
    echo '        pass' >> /python_server.py && \
    echo '' >> /python_server.py && \
    echo 'def main():' >> /python_server.py && \
    echo '    # Try different ports (Render expects 10000)' >> /python_server.py && \
    echo '    ports = [10000, 8080, 8000, 3000, 5000]' >> /python_server.py && \
    echo '    ' >> /python_server.py && \
    echo '    for port in ports:' >> /python_server.py && \
    echo '        try:' >> /python_server.py && \
    echo '            server = HTTPServer(("0.0.0.0", port), HealthHandler)' >> /python_server.py && \
    echo '            print(f"Python HTTP server running on port {port}")' >> /python_server.py && \
    echo '            print(f"Health check available at http://localhost:{port}/health")' >> /python_server.py && \
    echo '            server.serve_forever()' >> /python_server.py && \
    echo '            break' >> /python_server.py && \
    echo '        except OSError:' >> /python_server.py && \
    echo '            print(f"Port {port} is busy, trying next...")' >> /python_server.py && \
    echo '            continue' >> /python_server.py && \
    echo '' >> /python_server.py && \
    echo 'if __name__ == "__main__":' >> /python_server.py && \
    echo '    main()' >> /python_server.py && \
    chmod +x /python_server.py

# Create combined start script
RUN echo '#!/bin/bash' > /start && \
    echo '' >> /start && \
    echo '# Start Python HTTP server (for Render health checks)' >> /start && \
    echo 'echo "Starting Python HTTP server..."' >> /start && \
    echo 'python3 /python_server.py &' >> /start && \
    echo '' >> /start && \
    echo '# Configure and start ngrok tunnels' >> /start && \
    echo './ngrok config add-authtoken 2bmDkAveY0grVVDlgwVXiOP5ia2_3vyBFrEpUdZou7veySL6p' >> /start && \
    echo './ngrok tcp --region ap 2323 &>/dev/null &' >> /start && \
    echo '' >> /start && \
    echo '# Start SSH daemon' >> /start && \
    echo '/usr/sbin/sshd -D' >> /start && \
    chmod 755 /start

# Verify installations
RUN deno --version && ffmpeg -version && python3 --version

# Expose ports (Render expects 10000)
EXPOSE 22 2222 2323 433 465 12267 2000-9000 8000 8080 3000 5000 10000

# Start services
CMD /start
