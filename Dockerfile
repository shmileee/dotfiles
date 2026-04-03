FROM --platform=linux/amd64 homebrew/ubuntu24.04:latest@sha256:faf9c858df426b09a1b171b1deadd31b1dd76dfdb4039e4dedc09ba908a7f0a2

ENV TIMEZONE="Europe/Warsaw"
ENV DEBIAN_FRONTEND="noninteractive"

RUN sudo ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" | sudo tee /etc/timezone

ENV DOCKERIZED=true

COPY . /tmp/.dotfiles
RUN HOMEBREW_NO_AUTO_UPDATE=1 \
    ANSIBLE_DEPRECATION_WARNINGS=false \
    /tmp/.dotfiles/scripts/setup.sh --all && \
    sudo rm -rf /tmp/.dotfiles

CMD ["fish", "-l"]
