FROM homebrew/ubuntu20.04:3.4.2

# Assume root user to install system dependencies.
USER root

ENV TIMEZONE "Europe/Warsaw"
ENV DEBIAN_FRONTEND=noninteractive

# Setup time zones.
RUN ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && \
    echo $TIMEZONE > /etc/timezones

COPY ./scripts/linux /tmp/scripts/linux

# Install essential Linux dependencies.
RUN /tmp/scripts/linux/install_dependencies.sh

# Set build environment variables.
ENV USER linuxbrew

# Assume the user back.
USER $USER
ENV USER_HOME /home/$USER
ENV DOCKERIZED true
WORKDIR $USER_HOME

COPY ./scripts/common/install_brew.sh /tmp/scripts/common/install_brew.sh
RUN /tmp/scripts/common/install_brew.sh

COPY --chown=linuxbrew ./scripts/common/ansible.sh /tmp/scripts/common/ansible.sh
RUN /tmp/scripts/common/ansible.sh --install

# Setup the dotfiles directory.
ENV DOTFILES_DIR $USER_HOME/dotfiles

COPY --chown=linuxbrew ./scripts/common/ansible.sh /tmp/scripts/common/ansible.sh
COPY --chown=linuxbrew . $DOTFILES_DIR

CMD exec $DOTFILES_DIR/scripts/common/ansible.sh --run

# Start fish shell.
# CMD fish
