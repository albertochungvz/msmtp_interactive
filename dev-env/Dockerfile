FROM ubuntu:22.04

ENV container docker
ENV DEBIAN_FRONTEND=noninteractive

# Install only essential packages for a minimal Ubuntu Server with SSH access
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        systemd systemd-sysv \
        openssh-server \
        sudo \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Basic SSH configuration
RUN mkdir /var/run/sshd && \
    echo 'root:rootpass' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

# Create non-root user with sudo privileges
ARG USERNAME=devuser
ARG USERPASS=devpass
RUN useradd -m -s /bin/bash $USERNAME && \
    echo "$USERNAME:$USERPASS" | chpasswd && \
    usermod -aG sudo $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Expose SSH port
EXPOSE 22

# Volume for cgroups (systemd)
VOLUME [ "/sys/fs/cgroup" ]

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
