FROM ubuntu:jammy

# Set build environment variables.
ENV DOCKERIZED true
ENV USER shmileee
ENV TIMEZONE "Europe/Warsaw"
ENV DEBIAN_FRONTEND=noninteractive

# Setup time zones .
RUN ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && \
    echo $TIMEZONE > /etc/timezones

COPY ./scripts/linux /tmp/scripts/linux

# Install essential Linux dependencies.
RUN /tmp/scripts/linux/install_dependencies.sh

# Adds a new user to the sudo group
RUN useradd -ms /bin/bash $USER && \
    usermod -a -G sudo $USER && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY ./scripts/common /tmp/scripts/common
RUN /tmp/scripts/common/install_brew.sh

# Assume the user.
USER $USER
ENV USER_HOME /home/$USER
WORKDIR $USER_HOME

# Setup the dotfiles directory.
ENV DOTFILES_DIR $USER_HOME/dotfiles

COPY --chown=shmileee . $DOTFILES_DIR

# RUN $DOTFILES_DIR/setup.sh --ansible

# Start fish shell.
# CMD fish