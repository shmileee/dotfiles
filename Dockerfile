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

COPY ./scripts/common/install_brew.sh /tmp/scripts/common/install_brew.sh
RUN /tmp/scripts/common/install_brew.sh

# Assume the user.
USER $USER
ENV USER_HOME /home/$USER
WORKDIR $USER_HOME

COPY --chown=shmileee ./scripts/common/ansible.sh /tmp/scripts/common/ansible.sh
RUN /tmp/scripts/common/ansible.sh --install

# Setup the dotfiles directory.
ENV DOTFILES_DIR $USER_HOME/dotfiles

COPY --chown=shmileee ./scripts/common/ansible.sh /tmp/scripts/common/ansible.sh
RUN /tmp/scripts/common/ansible.sh --install

COPY --chown=shmileee . $DOTFILES_DIR

CMD exec $DOTFILES_DIR/scripts/common/ansible.sh --run

# Start fish shell.
# CMD fish
