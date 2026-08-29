# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

ENV TIMEZONE="Europe/Warsaw"
ENV DEBIAN_FRONTEND="noninteractive"
ENV DOCKERIZED=true
ENV ANSIBLE_DEPRECATION_WARNINGS=false
ENV HOME="/home/linuxbrew"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

SHELL ["/bin/sh", "-c"]

USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install --yes --no-install-recommends curl sudo && \
    groupmod --new-name linuxbrew ubuntu && \
    usermod --login linuxbrew --home /home/linuxbrew --move-home ubuntu && \
    echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/linuxbrew && \
    chmod 0440 /etc/sudoers.d/linuxbrew && \
    ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    ! command -v git

USER linuxbrew
COPY --chown=linuxbrew:linuxbrew . /bootstrap-source
WORKDIR /bootstrap-source

# Exercise the setup implementation from this build context. The persistent
# checkout is still created by Ansible at its normal workstation path.
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000,gid=1000 \
    GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || true)" && \
    export GITHUB_TOKEN HOMEBREW_GITHUB_API_TOKEN="$GITHUB_TOKEN" && \
    export HOMEBREW_NO_AUTO_UPDATE=1 GIT_CONFIG_COUNT=1 && \
    export GIT_CONFIG_KEY_0=http.version GIT_CONFIG_VALUE_0=HTTP/1.1 && \
    ./scripts/setup.sh && \
    cd / && \
    rm -rf /bootstrap-source

WORKDIR /home/linuxbrew/ghq/personalgit/shmileee/dotfiles

CMD ["fish", "-l"]
