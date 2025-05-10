# README.md

## Overview

This script (`serversetup.sh`) bootstraps a **fresh Hetzner Ubuntu 24.04** server with:

1. **System update/upgrade**
2. **Installation** of UFW, Fail2Ban, unattended-upgrades
3. **Creation** of a non-root sudo user (`$NEW_USER`, default `deploy`), and population of its SSH key(s)
4. **Firewall** configured to allow only your SSH port
5. **SSH hardening**: keys-only, root disabled, custom port, binding to all interfaces
6. **Automatic security updates** via unattended-upgrades
7. **Fail2Ban jail** for SSH

---

## Environment Variables

* `SSH_PORT` (default: `22`)
  The port on which SSH will listen.

* `NEW_USER` (default: `deploy`)
  The non-root user account created with passwordless sudo.

* `ADMIN_EMAIL` (optional)
  Email address to receive unattended-upgrades reports.

* `NEW_USER_PUBKEY` (optional)
  If set, its value (one line containing an SSH public-key) will be written into the new user’s `~/.ssh/authorized_keys`.
  Otherwise, the script copies `/root/.ssh/authorized_keys` (the key Hetzner injected for `root`) into the new user’s `~/.ssh/authorized_keys`.

---

## Usage

1. **Obtain the script**
   Upload `setup.sh` to your server, or pipe it directly:

   ```bash
   scp setup.sh root@YOUR.SERVER.IP:/root/
   ```
   or
   ```bash
   ssh root@YOUR.SERVER.IP 'bash -s' < serversetup.sh
   ```
2. **Run with custom variables**
   From your local machine, invoke:
   ```bash
   ssh root@YOUR.SERVER.IP \
    'SSH_PORT=2222 \
    NEW_USER=deploy \
    ADMIN_EMAIL=you@example.com \
    NEW_USER_PUBKEY="$(< ~/.ssh/id_rsa.pub)" \
    bash -s' < serversetup.sh
   ```
   If you omit NEW_USER_PUBKEY, the script will copy the existing /root/.ssh/authorized_keys into the new account.
3. **Log in**
   Once the script finishes:
   ```bash
   ssh -p 2222 deploy@YOUR.SERVER.IP
   sudo -i
   ```
4. **Verify**
   ```ufw status``` — confirm your firewall rules.

   ```ss -tulpn | grep sshd``` — ensure SSH is listening on your custom port.

   Inspect ```/etc/apt/apt.conf.d/50unattended-upgrades``` for your ```ADMIN_EMAIL```.
   
   ```fail2ban-client status sshd``` — confirm the SSH jail is active.

Your server is now patched, firewalled, and hardened with best-practice SSH access via a non-root sudo user.