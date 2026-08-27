#!/usr/bin/env bash

set -euoE pipefail

cwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
action=""
extra_playbook_opts=()

needs_become_pass() { ! sudo -n true 2>/dev/null; }

install_collections() {
	echo "⚪ [ansible] installing collections..."
	ansible-galaxy collection install community.general ansible.posix
}

run_playbook() {
	echo "⚪ [ansible] running playbook..."
	local playbook_opts=("${extra_playbook_opts[@]}")

	if needs_become_pass; then
		playbook_opts+=("--ask-become-pass")
	fi

	export ANSIBLE_CONFIG="${cwd}/ansible/ansible.cfg"

	if [[ -z "${CI:-}" && -z "${DOCKERIZED:-}" ]]; then
		playbook_opts+=("-v")
	fi

	echo "ansible-playbook -e ansible_user=$(whoami) ${cwd}/ansible/main.yaml ${playbook_opts[*]}"
	ansible-playbook -e "ansible_user=$(whoami)" "${cwd}/ansible/main.yaml" "${playbook_opts[@]}"
	echo "✅ [ansible] configured!"
}

while [[ $# -gt 0 ]]; do
	arg=$1
	case $arg in
	--install)
		action="install"
		;;
	--run)
		action="run"
		;;
	--all)
		action="all"
		;;
	--check)
		extra_playbook_opts+=("--check")
		;;
	*)
		echo "Unknown argument: $arg" >&2
		exit 1
		;;
	esac
	shift
done

case $action in
install)
	install_collections
	;;
run)
	run_playbook
	;;
all)
	install_collections
	run_playbook
	;;
*)
	echo "Usage: $0 --install|--run|--all [--check]" >&2
	exit 1
	;;
esac
