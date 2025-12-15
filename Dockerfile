FROM ubuntu:24.04

ARG BUILD_TIME
LABEL org.opencontainers.image.created="${BUILD_TIME}"

# Add Docker repository for docker-ce-cli
RUN apt-get update && apt-get install -y ca-certificates curl \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    iptables \
    curl \
    direnv \
    dnsutils \
    fd-find \
    fzf \
    git \
    iputils-ping \
    jq \
    neovim \
    ripgrep \
    sudo \
    tmux \
    wget \
    zsh \
    # Required for claude to be installed
    libatomic1 \
    && rm -rf /var/lib/apt/lists/*

RUN userdel -r ubuntu 2>/dev/null || true \
    && groupdel ubuntu 2>/dev/null || true \
    && groupadd -g 1000 claudo \
    && useradd -m -u 1000 -g 1000 -s /bin/zsh claudo \
    && usermod -aG docker claudo \
    && echo "claudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claudo \
    && chmod 0440 /etc/sudoers.d/claudo

ENV HOSTNAME=claudo
ENV TERM=xterm-256color
ENV CLAUDE_CONFIG_DIR=/home/claudo/.claude
ENV BUILD_TIME="${BUILD_TIME}"

USER claudo
WORKDIR /home/claudo
ENV PATH="/home/claudo/.local/bin:$PATH"

# Create /workspaces/tmp for --tmp mode with correct ownership
USER root
RUN mkdir -p /workspaces/tmp && chown claudo:claudo /workspaces/tmp
USER claudo

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create symlink for fd (Ubuntu installs it as fdfind)
RUN mkdir -p /home/claudo/.local/bin && ln -s $(which fdfind) /home/claudo/.local/bin/fd

COPY --chown=claudo:claudo entrypoint.sh /home/claudo/.local/bin/entrypoint.sh
COPY --chown=claudo:claudo docker-init.sh /home/claudo/.local/bin/docker-init.sh
RUN chmod +x /home/claudo/.local/bin/entrypoint.sh /home/claudo/.local/bin/docker-init.sh

ENTRYPOINT ["/home/claudo/.local/bin/entrypoint.sh"]
