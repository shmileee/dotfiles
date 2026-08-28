# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

ENV TIMEZONE="Europe/Warsaw"
ENV DEBIAN_FRONTEND="noninteractive"
ENV DOCKERIZED=true
ENV ANSIBLE_DEPRECATION_WARNINGS=false
ENV HOME="/home/linuxbrew"
ENV PATH="/home/linuxbrew/.local/share/dotfiles/ansible-core/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

SHELL ["/bin/sh", "-eu", "-c"]

USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install --yes --no-install-recommends ca-certificates sudo && \
    groupmod --new-name linuxbrew ubuntu && \
    usermod --login linuxbrew --home /home/linuxbrew --move-home ubuntu && \
    echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/linuxbrew && \
    chmod 0440 /etc/sudoers.d/linuxbrew && \
    ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone
USER linuxbrew
WORKDIR /tmp/.dotfiles

COPY --chown=linuxbrew:linuxbrew scripts ./scripts
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    scripts/docker/profile.sh native-dependencies scripts/setup.sh --deps
RUN scripts/docker/profile.sh homebrew scripts/setup.sh --brew
RUN --mount=type=cache,target=/home/linuxbrew/.cache/pip,uid=1000,gid=1000,sharing=locked \
    scripts/docker/profile.sh ansible-engine scripts/common/install_ansible.sh
RUN mkdir -p /home/linuxbrew/.local/share/mise

COPY --chown=linuxbrew:linuxbrew . .
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000,gid=1000 \
    --mount=type=cache,target=/home/linuxbrew/.cache/Homebrew,uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target=/home/linuxbrew/.local/share/mise/downloads,uid=1000,gid=1000,sharing=locked \
    GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || true)" && \
    export GITHUB_TOKEN && \
    export HOMEBREW_GITHUB_API_TOKEN="${GITHUB_TOKEN}" && \
    export HOMEBREW_NO_AUTO_UPDATE=1 && \
    export GIT_CONFIG_COUNT=1 && \
    export GIT_CONFIG_KEY_0=http.version && \
    export GIT_CONFIG_VALUE_0=HTTP/1.1 && \
    scripts/docker/profile.sh workstation-playbook scripts/common/ansible.sh --all

CMD ["fish", "-l"]
