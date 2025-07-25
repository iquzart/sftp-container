#!/bin/bash
set -e

# ==== Logging Helpers ====
log() {
  local level="$1"
  shift
  local color reset

  case "$level" in
  DEBUG)
    [[ "$LOG_LEVEL" == "DEBUG" ]] || return
    color='\033[0;36m'
    ;;
  INFO) color='\033[0;32m' ;;
  ERROR) color='\033[0;31m' ;;
  *) color='' ;;
  esac
  reset='\033[0m'
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${color}[$level]${reset} $*"
}

# Disabled the banner - I hate this
# ascii_banner() {
#   cat <<'EOF'
#
#     == ro-sftp ==
#     Read-Only | Single User | SFTP Server
#
# EOF
# }
#
# ascii_banner
log INFO "SFTP Home: $SFTP_HOME"
log INFO "SFTP Directory: $SFTP_HOME/$SFTP_DIR_NAME"
log INFO "Listening on port $SFTP_PORT"
log INFO "Starting SSH daemon..."

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config -p "$SFTP_PORT" -o PidFile=none
