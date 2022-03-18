FROM ubuntu:jammy

# Set build environment variables.
ENV DOCKERIZED true
ENV USER shmileee
ENV TIMEZONE "Europe/Warsaw"
ARG DEBIAN_FRONTEND=noninteractive

# Setup time zones and install linux dependencies needed for build.
RUN ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && \
    echo $TIMEZONE > /etc/timezones && \
    apt update -y && \
    apt install -y sudo curl && \
    apt clean

# Adds a new user to the sudo group
RUN useradd -ms /bin/bash $USER && \
    usermod -a -G sudo $USER && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Assume the user.
USER $USER
ENV USER_HOME /home/$USER
WORKDIR $USER_HOME

# Setup the dotfiles directory.
ENV DOTFILES_DIR $USER_HOME/dotfiles

COPY --chown=shmileee . $DOTFILES_DIR

# RUN $DOTFILES_DIR/setup.sh

# Start fish shell.
# CMD fish
