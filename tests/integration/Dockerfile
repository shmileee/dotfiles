# syntax=docker/dockerfile:1.7

FROM ghcr.io/astral-sh/uv:0.12.6 AS uv

FROM ubuntu:latest AS ubuntu-bootstrap-integration

ENV HOME=/home/linuxbrew
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=uv /uv /usr/local/bin/uv

USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install --yes --no-install-recommends curl sudo && \
    if getent passwd ubuntu >/dev/null; then \
      groupmod --new-name linuxbrew ubuntu && \
      usermod --login linuxbrew --home /home/linuxbrew --move-home ubuntu; \
    else \
      groupadd --gid 1000 linuxbrew && \
      useradd --uid 1000 --gid linuxbrew --create-home --shell /bin/bash linuxbrew; \
    fi && \
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
      --requirements-file bootstrap/ansible/requirements.yml

RUN ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      --syntax-check bootstrap/ansible/main.yaml

RUN ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    uv run --project bootstrap --locked --managed-python \
      python bootstrap/validate_runtime.py \
      --uv-executable /usr/local/bin/uv \
      --collections-path /tmp/ansible-collections \
      --checkout /source

RUN ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT=/home/linuxbrew/bootstrap-integration/dotfiles \
    DOTFILES_PERSISTENT_REPOSITORY_URL="$(./bootstrap/setup.sh --print-config | sed -n 's/^repository_url=//p')" \
    DOTFILES_PERSISTENT_REF="$(./bootstrap/setup.sh --print-config | sed -n 's/^repository_ref=//p')" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags bootstrap_prerequisites \
      bootstrap/ansible/main.yaml

RUN ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT=/home/linuxbrew/bootstrap-integration/dotfiles \
    DOTFILES_PERSISTENT_REPOSITORY_URL="$(./bootstrap/setup.sh --print-config | sed -n 's/^repository_url=//p')" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags homebrew_install \
      bootstrap/ansible/main.yaml

RUN test -x /home/linuxbrew/.linuxbrew/bin/brew && \
    /home/linuxbrew/.linuxbrew/bin/brew --version

RUN ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT=/home/linuxbrew/bootstrap-integration/dotfiles \
    DOTFILES_PERSISTENT_REPOSITORY_URL="$(./bootstrap/setup.sh --print-config | sed -n 's/^repository_url=//p')" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags homebrew_install \
      bootstrap/ansible/main.yaml | tee /tmp/homebrew-idempotence.log && \
    grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/homebrew-idempotence.log

RUN repository=/home/linuxbrew/bootstrap-integration/dotfiles && \
    repository_url="$(./bootstrap/setup.sh --print-config | sed -n 's/^repository_url=//p')" && \
    test -x /usr/bin/git && \
    test -s /etc/ssl/certs/ca-certificates.crt && \
    test "$(git -C "$repository" remote get-url origin)" = "$repository_url" && \
    test -z "$(git -C "$repository" config --local --get http.sslVerify || true)" && \
    test "$(git -C "$repository" rev-parse --is-shallow-repository)" = false && \
    test -z "$(git -C "$repository" config --local --get remote.origin.promisor || true)"

RUN ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT=/home/linuxbrew/bootstrap-integration/dotfiles \
    DOTFILES_PERSISTENT_REPOSITORY_URL="$(./bootstrap/setup.sh --print-config | sed -n 's/^repository_url=//p')" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags bootstrap_prerequisites \
      bootstrap/ansible/main.yaml | tee /tmp/prerequisites-idempotence.log && \
    grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/prerequisites-idempotence.log

RUN repository=/home/linuxbrew/bootstrap-integration/dotfiles && \
    expected_commit="$(git -C "$repository" rev-parse HEAD)" && \
    ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT="$repository" \
    DOTFILES_PERSISTENT_REPOSITORY_URL="$(git -C "$repository" remote get-url origin)" \
    DOTFILES_PERSISTENT_EXPECTED_COMMIT="$expected_commit" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --check \
      --tags bootstrap_prerequisites \
      bootstrap/ansible/main.yaml

RUN handoff_target=/tmp/handoff-checkout && \
    fake_bin=/tmp/handoff-bin && \
    mkdir -p "$handoff_target/.git" "$fake_bin" && \
    cp tests/bootstrap/fake-mise.sh "$fake_bin/mise" && \
    chmod +x "$fake_bin/mise" && \
    : > /tmp/mise.log && \
    PATH="$fake_bin:$PATH" \
    MISE_LOG=/tmp/mise.log \
    ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT="$handoff_target" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags handoff \
    bootstrap/ansible/main.yaml && \
    test "$(cat "$handoff_target/.git/dotfiles-bootstrap-complete")" = \
      'locked runtime validated' && \
    PATH="$fake_bin:$PATH" \
    MISE_LOG=/tmp/mise.log \
    ANSIBLE_CONFIG=bootstrap/ansible/ansible.cfg \
    ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-collections \
    DOTFILES_PERSISTENT_CHECKOUT="$handoff_target" \
    uv run --project bootstrap --locked --managed-python \
      ansible-playbook --inventory '127.0.0.1,' \
      -e ansible_user=linuxbrew \
      --tags handoff \
      bootstrap/ansible/main.yaml | tee /tmp/handoff-idempotence.log && \
    grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/handoff-idempotence.log && \
    test "$(wc -l < /tmp/mise.log)" -eq 6 && \
    grep -F 'exec -- uv' /tmp/mise.log >/dev/null && \
    grep -F 'ansible-galaxy collection install' /tmp/mise.log >/dev/null && \
    grep -F 'ansible-playbook --version' /tmp/mise.log >/dev/null
