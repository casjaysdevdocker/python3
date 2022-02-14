#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202202021753-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.com
# @License       : WTFPL
# @ReadME        : entrypoint.sh --help
# @Copyright     : Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @Created       : Wednesday, Feb 02, 2022 17:53 EST
# @File          : entrypoint.sh
# @Description   :
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202202021753-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
trap 'exitCode=${exitCode:-$?};[ -n "$ENTRYPOINT_SH_TEMP_FILE" ] && [ -f "$ENTRYPOINT_SH_TEMP_FILE" ] && rm -Rf "$ENTRYPOINT_SH_TEMP_FILE" &>/dev/null' EXIT
__exec_bash() { [ -n "$1" ] && exec /bin/bash -l -c "${@:-bash}" || exec /bin/bash -l; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export TZ="${TZ:-America/New_York}"
export HOSTNAME="${HOSTNAME:-casjaysdev-alpine}"

[ -n "${TZ}" ] && echo "${TZ}" >/etc/timezone
[ -n "${HOSTNAME}" ] && echo "${HOSTNAME}" >/etc/hostname
[ -n "${HOSTNAME}" ] && echo "127.0.0.1 $HOSTNAME localhost" >/etc/hosts
[ -f "/usr/share/zoneinfo/${TZ}" ] && ln -sf "/usr/share/zoneinfo/${TZ}" "/etc/localtime"

case $1 in
healthcheck)
  echo 'OK'
  ;;
bash | shell | sh | /bin/bash | /bin/sh)
  shift 1
  __exec_bash "$@"
  ;;
*)
  [ -f "/app/venv/bin/activate" ] && . "/app/venv/bin/activate"
  [ -f "/app/.venv/bin/activate" ] && . "/app/.venv/bin/activate"
  if [ $# -gt 0 ]; then
    exec "$@"
  elif [ -f "requirements.txt" ]; then
    pip install -r "./requirements.txt"
  fi
  ;;
esac
