# syntax=docker/dockerfile:1.7

FROM ghcr.io/astral-sh/uv:0.12.6 AS uv

FROM ubuntu:24.04 AS ubuntu-bootstrap-integration

ENV HOME=/home/linuxbrew
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=uv /uv /usr/local/bin/uv

USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install --yes --no-install-recommends curl sudo && \
    groupmod --new-name linuxbrew ubuntu && \
    usermod --login linuxbrew --home /home/linuxbrew --move-home ubuntu && \
    echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/linuxbrew && \
    chmod 0440 /etc/sudoers.d/linuxbrew && \
    ! command -v git && \
    ! test -e /etc/ssl/certs/ca-certificates.crt

COPY --chown=linuxbrew:linuxbrew . /source

USER linuxbrew
WORKDIR /source

# uv verifies downloads with its bundled roots. Galaxy uses Python's absent
# system bundle, so only that pre-Ansible call ignores certificates. The first
# Ansible task installs and updates ca-certificates.
RUN uv sync --project bootstrap --locked --managed-python && \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    uv run --project bootstrap --locked --managed-python \
      ansible-galaxy collection install --ignore-certs \
      --collections-path /tmp/ansible-collections \
      --requirements-file scripts/common/ansible/requirements.yml

RUN ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      --syntax-check scripts/common/ansible/main.yaml

RUN ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT=/home/linuxbrew/ghq/personalgit/shmileee/dotfiles \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags bootstrap_prerequisites \
      scripts/common/ansible/main.yaml

RUN repository=/home/linuxbrew/ghq/personalgit/shmileee/dotfiles && \
    test -x /usr/bin/git && \
    test -s /etc/ssl/certs/ca-certificates.crt && \
    test "$(git -C "$repository" remote get-url origin)" = \
      https://github.com/shmileee/dotfiles.git && \
    test -z "$(git -C "$repository" config --local --get http.sslVerify || true)" && \
    test "$(git -C "$repository" rev-parse --is-shallow-repository)" = false && \
    test -z "$(git -C "$repository" config --local --get remote.origin.promisor || true)"

RUN ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT=/home/linuxbrew/ghq/personalgit/shmileee/dotfiles \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags bootstrap_prerequisites \
      scripts/common/ansible/main.yaml | tee /tmp/prerequisites-idempotence.log && \
    grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/prerequisites-idempotence.log

RUN handoff_target=/tmp/handoff-checkout && \
    fake_bin=/tmp/handoff-bin && \
    mkdir -p "$handoff_target/.git" "$fake_bin" && \
    cp tests/bootstrap/fake-mise.sh "$fake_bin/mise" && \
    chmod +x "$fake_bin/mise" && \
    : > /tmp/mise.log && \
    PATH="$fake_bin:$PATH" \
    MISE_LOG=/tmp/mise.log \
    ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT="$handoff_target" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags handoff \
    scripts/common/ansible/main.yaml && \
    test "$(cat "$handoff_target/.git/dotfiles-bootstrap-complete")" = \
      'locked runtime validated' && \
    PATH="$fake_bin:$PATH" \
    MISE_LOG=/tmp/mise.log \
    ANSIBLE_CONFIG=scripts/common/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT="$handoff_target" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags handoff \
      scripts/common/ansible/main.yaml | tee /tmp/handoff-idempotence.log && \
    grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/handoff-idempotence.log && \
    test "$(wc -l < /tmp/mise.log)" -eq 4 && \
    grep -F 'exec -- uv' /tmp/mise.log >/dev/null && \
    grep -F 'ansible-playbook --version' /tmp/mise.log >/dev/null
