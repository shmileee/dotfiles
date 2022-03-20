FROM homebrew/ubuntu20.04:3.4.2

# Assume root user to install system dependencies.
USER root

ENV TIMEZONE "Europe/Warsaw"
ENV DEBIAN_FRONTEND=noninteractive

# +Setup time zones.
RUN ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && \
    echo $TIMEZONE > /etc/timezones

# Set build environment variables.
ENV USER linuxbrew

# Assume the user back.
USER $USER
ENV USER_HOME /home/$USER
ENV DOCKERIZED true
WORKDIR $USER_HOME

# Configure dotfiles.
COPY ./scripts/setup.sh /tmp/setup.sh
RUN /tmp/setup.sh --all

# Start fish shell.
CMD ["fish", "-l"]
