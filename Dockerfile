FROM --platform=linux/amd64 homebrew/ubuntu24.04:latest@sha256:ba10c293072721071cafdba7d1a396979f06ee623bf48abf55c9e84cb15f945b

ENV TIMEZONE="Europe/Warsaw"
ENV DEBIAN_FRONTEND="noninteractive"

RUN sudo ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" | sudo tee /etc/timezone

ENV DOCKERIZED=true

COPY . /tmp/.dotfiles
RUN --mount=type=secret,id=GITHUB_TOKEN,env=GITHUB_TOKEN \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_GITHUB_API_TOKEN="${GITHUB_TOKEN}" \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=http.version \
    GIT_CONFIG_VALUE_0=HTTP/1.1 \
    ANSIBLE_DEPRECATION_WARNINGS=false \
    /tmp/.dotfiles/scripts/setup.sh --all && \
    sudo rm -rf /tmp/.dotfiles

CMD ["fish", "-l"]
