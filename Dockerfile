FROM homebrew/ubuntu24.04:latest@sha256:2ff66a5c566a3261f4881010b545f4f38a9d8b22ab093184457563c442819039

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
