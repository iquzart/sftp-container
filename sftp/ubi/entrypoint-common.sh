#!/bin/bash
set -e

# ==== Default Config ====
: "${SFTP_USER:=user1}"
: "${SFTP_KEY_PATH:=/config/authorized_keys}"
: "${SFTP_HOME:=/home/${SFTP_USER}}"
: "${SFTP_DIR_NAME:=download}"
: "${LOG_LEVEL:=INFO}"

# ==== Distribution Detection ====
detect_distribution() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "$ID"
  elif [[ -f /etc/redhat-release ]]; then
    echo "rhel"
  else
    echo "unknown"
  fi
}

# ==== Path Resolution ====
get_nologin_path() {
  local distro="$1"
  case "$distro" in
  debian | ubuntu)
    echo "/usr/sbin/nologin"
    ;;
  rhel | centos | fedora | almalinux | rocky)
    if [[ -f /sbin/nologin ]]; then
      echo "/sbin/nologin"
    else
      echo "/usr/sbin/nologin"
    fi
    ;;
  *)
    # Try to find nologin in common locations
    if [[ -f /usr/sbin/nologin ]]; then
      echo "/usr/sbin/nologin"
    elif [[ -f /sbin/nologin ]]; then
      echo "/sbin/nologin"
    else
      echo "/bin/false" # fallback
    fi
    ;;
  esac
}

get_sshd_path() {
  if [[ -f /usr/sbin/sshd ]]; then
    echo "/usr/sbin/sshd"
  elif [[ -f /sbin/sshd ]]; then
    echo "/sbin/sshd"
  else
    log ERROR "SSHD binary not found"
    exit 1
  fi
}

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
generate_host_keys() {
  if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    log INFO "Generating SSH host keys..."
    ssh-keygen -A >/dev/null 2>&1
  fi
}

# ==== User Management ====
create_sftp_user() {
  local user="$1"
  local home_dir="$2"
  local shell_path="$3"

  if ! id "$user" &>/dev/null; then
    log INFO "Creating user $user"
    useradd -m -d "$home_dir" -s "$shell_path" "$user"
  else
    log DEBUG "User $user already exists"
  fi
}

# ==== SSH Key Setup ====
setup_ssh_keys() {
  local user="$1"
  local home_dir="$2"
  local key_path="$3"

  mkdir -p "$home_dir/.ssh"
  chmod 700 "$home_dir/.ssh"

  if [[ -f "$key_path" ]]; then
    cp "$key_path" "$home_dir/.ssh/authorized_keys"
    chmod 600 "$home_dir/.ssh/authorized_keys"
    chown -R "$user:$user" "$home_dir/.ssh"
    log INFO "Authorized keys installed for $user"
  else
    log ERROR "authorized_keys not found at $key_path"
  fi
}

# ==== Chroot Jail Setup ====
setup_chroot_jail() {
  local home_dir="$1"

  chown root:root "$home_dir"
  chmod 755 "$home_dir"
}

# ==== SFTP Directory Setup ====
setup_sftp_directory() {
  local user="$1"
  local sftp_dir="$2"

  mkdir -p "$sftp_dir"
  chown "$user:$user" "$sftp_dir"
  chmod 700 "$sftp_dir"
  log INFO "Created and set permissions on $sftp_dir"
}

# ==== SSHD Startup ====
start_sshd() {
  local sshd_path="$1"

  log INFO "Launching SSHD..."
  exec "$sshd_path" -D -e
}

# ==== Main Execution ====
main() {
  # Detect distribution and get appropriate paths
  local distro=$(detect_distribution)
  local nologin_path=$(get_nologin_path "$distro")
  local sshd_path=$(get_sshd_path)
  local sftp_dir="$SFTP_HOME/$SFTP_DIR_NAME"

  log INFO "Detected distribution: $distro"
  log INFO "Using nologin shell: $nologin_path"
  log INFO "Using SSHD binary: $sshd_path"
  log INFO "Starting SFTP server for user: $SFTP_USER"

  # Execute setup steps
  generate_host_keys
  create_sftp_user "$SFTP_USER" "$SFTP_HOME" "$nologin_path"
  setup_ssh_keys "$SFTP_USER" "$SFTP_HOME" "$SFTP_KEY_PATH"
  setup_chroot_jail "$SFTP_HOME"
  setup_sftp_directory "$SFTP_USER" "$sftp_dir"
  start_sshd "$sshd_path"
}

# Execute main function
main "$@"

