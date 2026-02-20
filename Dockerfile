FROM debian:12-slim

# Install essential packages and Rust
RUN apt-get -y update && apt-get -y upgrade && \
    apt-get install -y sudo curl git locales nano python3-pip screen ssh unzip wget ca-certificates build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js 21.x
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install -y nodejs

# Configure SSH
RUN mkdir /run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 22" >> /etc/ssh/sshd_config && \
    echo "Port 2222" >> /etc/ssh/sshd_config

# Set root password
RUN echo root:choco | chpasswd

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
    echo './ngrok tcp --region ap 22 &>/dev/null &' >> /start && \
    echo './ngrok tcp --region ap 2222 &>/dev/null &' >> /start && \
    echo '/usr/sbin/sshd -D' >> /start && \
    chmod 755 /start

# Expose ports: 2000-9000 range, plus specific ports 22, 2222, 433, 12267
EXPOSE 22 2222 433 465 12267 2000-9000

# Start services
CMD /start
