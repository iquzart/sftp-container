# SFTP Hardened Server Images

# SFTP Hardened Server Images

[![Build Status](https://github.com/iquzart/sftp-container/actions/workflows/build-push.yml/badge.svg)](https://github.com/iquzart/sftp-container/actions/workflows/build-push.yml)
[![Container Image](https://img.shields.io/github/v/release/iquzart/sftp-container?logo=docker&label=container%20image)](https://github.com/iquzart/sftp-container/packages)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)]

...

This repository contains hardened SFTP server container images built on **Red Hat UBI 9** and **Debian** base images. Both images enforce key-based authentication, chroot jails, and CIS-compliant SSH hardening.

## Features

- Hardened OpenSSH server configuration
- Key-based authentication only, no password login
- User chroot jail with jailed directories
- No shell access for SFTP users
- Logs output to console for easier monitoring
- `docker-compose` files for quick local testing

## Usage

### Build and run locally (example for UBI)

```bash
cd sftp/ubi
docker-compose up
```

## Environment Variables (for runtime configuration)

| Variable        | Description                                    |
| --------------- | ---------------------------------------------- |
| `SFTP_USER`     | The SFTP username to create.                   |
| `SFTP_PUB_KEY`  | The public SSH key for authentication.         |
| `SFTP_DIR_NAME` | The name of the directory to chroot or expose. |

## Dynamic SSHD Configuration

To update SSH server settings without rebuilding the container image, you can mount a custom sshd_config file as a volume in your Kubernetes deployment or Docker setup. This allows you to change configurations on the fly, such as enabling or disabling features, updating ciphers, or adjusting logging verbosity.

### How to do it

Create or modify your sshd_config file locally.
Mount it into the container at /etc/ssh/sshd_config using a volume or ConfigMap.
Restart the SFTP container or pod to apply the new configuration.

```yaml

volumeMounts:
- name: sshd-config
  mountPath: /etc/ssh/sshd_config
  subPath: sshd_config
  volumes:
- name: sshd-config
  configMap:
  name: your-sshd-config-map
```

### Important

Ensure your mounted sshd_config is compatible with the OpenSSH version in the image.
Validate your config syntax with sshd -t before applying to avoid SSHD startup failures. Remember to keep your security settings hardened when making changes.
