FROM --platform=linux/amd64 homebrew/ubuntu24.04:latest@sha256:7c2c366ebb40bb9be461a7e40dae4f300b8f417ed2e23f3f90d66d5f8988f11f

ENV TIMEZONE="Europe/Warsaw"
ENV DEBIAN_FRONTEND="noninteractive"

RUN sudo ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" | sudo tee /etc/timezone

ENV DOCKERIZED=true

COPY . /tmp/.dotfiles
RUN /tmp/.dotfiles/scripts/setup.sh --all && \
    rm -rf /tmp/.dotfiles

CMD ["fish", "-l"]
