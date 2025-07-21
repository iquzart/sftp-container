#!/bin/bash
set -e

# ==== Default Config ====
: "${SFTP_USER:=user1}"
: "${SFTP_KEY_PATH:=/config/authorized_keys}"
: "${SFTP_HOME:=/home/${SFTP_USER}}"
: "${SFTP_DIR_NAME:=download}"
: "${LOG_LEVEL:=INFO}"

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

# ==== Host Key Generation ====
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    log INFO "Generating SSH host keys..."
    ssh-keygen -A >/dev/null 2>&1
fi

log INFO "Starting SFTP server for user: $SFTP_USER"

# ==== Create User ====
if ! id "$SFTP_USER" &>/dev/null; then
    log INFO "Creating user $SFTP_USER"
    useradd -m -d "$SFTP_HOME" -s /usr/sbin/nologin "$SFTP_USER"
else
    log DEBUG "User $SFTP_USER already exists"
fi

# ==== Setup SSH Key Authentication ====
mkdir -p "$SFTP_HOME/.ssh"
chmod 700 "$SFTP_HOME/.ssh"

if [[ -f "$SFTP_KEY_PATH" ]]; then
    cp "$SFTP_KEY_PATH" "$SFTP_HOME/.ssh/authorized_keys"
    chmod 600 "$SFTP_HOME/.ssh/authorized_keys"
    chown -R "$SFTP_USER:$SFTP_USER" "$SFTP_HOME/.ssh"
    log INFO "Authorized keys installed for $SFTP_USER"
else
    log ERROR "authorized_keys not found at $SFTP_KEY_PATH"
fi

# ==== Chroot Jail Permissions ====
chown root:root "$SFTP_HOME"
chmod 755 "$SFTP_HOME"

# ==== Writable SFTP Directory ====
SFTP_DIR="$SFTP_HOME/$SFTP_DIR_NAME"
mkdir -p "$SFTP_DIR"
chown "$SFTP_USER:$SFTP_USER" "$SFTP_DIR"
chmod 700 "$SFTP_DIR"
log INFO "Created and set permissions on $SFTP_DIR"

# ==== Start SSHD ====
log INFO "Launching SSHD..."
exec /usr/sbin/sshd -D -e