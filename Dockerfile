FROM homebrew/ubuntu24.04:latest@sha256:e35dc3078f051a7f0b19b61adf38782b8a0fb9fab8c138c4c76a4738bd8f5aed

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
