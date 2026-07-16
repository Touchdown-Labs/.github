#!/usr/bin/env bash

set -euo pipefail

RUNNER_VERSION="${RUNNER_VERSION:-2.335.1}"
RUNNER_SHA256="${RUNNER_SHA256:-b2fe57b2ae5b0bc1605f9fc0723c07eedf06167321d3478ce0440f15e5b0a010}"
RUNNER_LABEL="${RUNNER_LABEL:-touchdown-ci}"

usage() {
  echo "usage: $0 install|run|status|remove OWNER/REPOSITORY" >&2
  exit 2
}

command="${1:-}"
repository="${2:-}"
if [[ -z "$command" || -z "$repository" || "$repository" != */* ]]; then
  usage
fi

repo_slug="${repository//\//-}"
runner_root="${RUNNER_ROOT:-$HOME/.touchdown/github-runners/$repo_slug}"
runner_name="${RUNNER_NAME:-touchdown-$repo_slug}"
archive="actions-runner-osx-x64-${RUNNER_VERSION}.tar.gz"
download_url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${archive}"

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "this pinned runner helper currently supports macOS only" >&2
    exit 1
  fi
  if ! /usr/bin/pgrep -q oahd; then
    echo "Rosetta 2 is required for the pinned x64 runner" >&2
    exit 1
  fi
}

install_runner() {
  require_macos
  if [[ -e "$runner_root/.runner" ]]; then
    echo "runner is already configured at $runner_root" >&2
    exit 1
  fi

  mkdir -p "$runner_root"
  chmod 700 "$runner_root"
  umask 077
  archive_path="$runner_root/$archive"
  curl -fsSL "$download_url" -o "$archive_path"
  printf '%s  %s\n' "$RUNNER_SHA256" "$archive_path" | shasum -a 256 -c -
  tar -xzf "$archive_path" -C "$runner_root"
  rm -f "$archive_path"

  registration_token="$(
    gh api --method POST "repos/${repository}/actions/runners/registration-token" --jq .token
  )"
  (
    cd "$runner_root"
    ./config.sh \
      --unattended \
      --url "https://github.com/${repository}" \
      --token "$registration_token" \
      --name "$runner_name" \
      --labels "$RUNNER_LABEL" \
      --work _work \
      --replace
  )
}

run_runner() {
  require_macos
  if [[ ! -e "$runner_root/.runner" ]]; then
    echo "runner is not configured; run '$0 install $repository' first" >&2
    exit 1
  fi

  isolated_home="$runner_root/_home"
  isolated_tmp="$runner_root/_tmp"
  evidence_root="${TD_CI_EVIDENCE_ROOT:-$HOME/.touchdown/ci-evidence}"
  mkdir -p "$isolated_home" "$isolated_tmp" "$evidence_root"
  chmod 700 "$isolated_home" "$isolated_tmp" "$evidence_root"
  cd "$runner_root"
  exec env -i \
    HOME="$isolated_home" \
    USER="$(id -un)" \
    LOGNAME="$(id -un)" \
    PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    TMPDIR="$isolated_tmp/" \
    TD_CI_EVIDENCE_ROOT="$evidence_root" \
    LANG="${LANG:-en_US.UTF-8}" \
    SHELL="/bin/bash" \
    ./run.sh
}

runner_status() {
  gh api "repos/${repository}/actions/runners" \
    --jq '.runners[] | select(.name == "'"$runner_name"'") | {id, name, status, busy, labels: [.labels[].name]}'
}

remove_runner() {
  if [[ ! -e "$runner_root/.runner" ]]; then
    echo "runner is not configured at $runner_root"
    return
  fi
  removal_token="$(
    gh api --method POST "repos/${repository}/actions/runners/remove-token" --jq .token
  )"
  (
    cd "$runner_root"
    ./config.sh remove --token "$removal_token"
  )
  chmod -R u+rwX "$runner_root"
  rm -rf "$runner_root"
}

case "$command" in
  install) install_runner ;;
  run) run_runner ;;
  status) runner_status ;;
  remove) remove_runner ;;
  *) usage ;;
esac
