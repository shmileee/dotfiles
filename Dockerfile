FROM homebrew/ubuntu20.04:3.4.2

ENV TIMEZONE "Europe/Warsaw"
ENV DEBIAN_FRONTEND=noninteractive

# Setup time zones.
RUN sudo ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && \
    echo $TIMEZONE | sudo tee /etc/timezone

ENV DOCKERIZED true

# Configure dotfiles.
COPY ./scripts/setup.sh /tmp/setup.sh
RUN /tmp/setup.sh --all

# Start fish shell.
CMD ["fish", "-l"]
