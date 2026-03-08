FROM archlinux:latest

# Update system and install essential packages
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    sudo \
    curl \
    git \
    nano \
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

# Configure SSH
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config &&\
    echo "Port 2323" >> /etc/ssh/sshd_config

# Set root password
RUN echo "root:choco" | chpasswd

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

# Create start script with embedded auth token
RUN echo '#!/bin/bash' > /start && \
    echo './ngrok config add-authtoken 2bmDkAveY0grVVDlgwVXiOP5ia2_3vyBFrEpUdZou7veySL6p' >> /start && \
    echo './ngrok tcp --region ap 2323 &>/dev/null &' >> /start && \
    echo '/usr/sbin/sshd -D' >> /start && \
    chmod 755 /start

# Verify installations
RUN deno --version && ffmpeg -version

# Expose ports
EXPOSE 22 2222 2323 433 465 12267 2000-9000

# Start services
CMD /start
