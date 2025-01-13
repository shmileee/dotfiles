FROM homebrew/ubuntu24.04:latest@sha256:faf9c858df426b09a1b171b1deadd31b1dd76dfdb4039e4dedc09ba908a7f0a2

ENV TIMEZONE="Europe/Warsaw"
ENV DEBIAN_FRONTEND="noninteractive"

# Setup time zones.
RUN sudo ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && \
    echo $TIMEZONE | sudo tee /etc/timezone

ENV DOCKERIZED=true

# Configure dotfiles.
COPY ./scripts/setup.sh /tmp/setup.sh
RUN /tmp/setup.sh --all

# Start fish shell.
CMD ["fish", "-l"]
