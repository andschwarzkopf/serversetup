#!/usr/bin/env bash
#
# setup.sh — Ubuntu 24.04 hardening + non-root sudo user
#
# Usage (as root):
#   SSH_PORT=2222 NEW_USER=deploy ADMIN_EMAIL=you@example.com bash serversetup.sh
#
# (c) Andreas Schwarzkopf 2025
#
set -euo pipefail

### 0. Ensure we're root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "⚠️  Must be run as root." >&2
  exit 1
fi

### 1. Parameters from env (with defaults)
SSH_PORT="${SSH_PORT:-22}"
NEW_USER="${NEW_USER:-deploy}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"

### 2. System update & upgrade
echo "→ Updating & upgrading packages…"
apt update
DEBIAN_FRONTEND=noninteractive apt -y full-upgrade

### 3. Install security tools
echo "→ Installing ufw, fail2ban, unattended-upgrades…"
apt install -y ufw fail2ban unattended-upgrades apt-listchanges

### 4. Create non-root sudo user
echo "→ Creating sudo user '$NEW_USER'…"
if id "$NEW_USER" &>/dev/null; then
  echo "   User $NEW_USER already exists, skipping creation."
else
  adduser --disabled-password --gecos "" "$NEW_USER"
  mkdir -p /home/"$NEW_USER"/.ssh
  cp /root/.ssh/authorized_keys /home/"$NEW_USER"/.ssh/
  chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh
  chmod 700 /home/"$NEW_USER"/.ssh
  chmod 600 /home/"$NEW_USER"/.ssh/authorized_keys
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_"$NEW_USER"
  chmod 440 /etc/sudoers.d/90_"$NEW_USER"
fi

### 5. Configure UFW
echo "→ Setting up UFW (allow SSH on port $SSH_PORT)…"
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
ufw --force enable

### 6. Harden SSH config
echo "→ Hardening /etc/ssh/sshd_config…"
SSH_CFG=/etc/ssh/sshd_config
cp "$SSH_CFG" "${SSH_CFG}.orig.$(date +%Y%m%d%H%M)"

# disable password auth and root login
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "$SSH_CFG"
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/'        "$SSH_CFG"

### 7. Force custom SSH port & listen address
echo "→ Forcing SSH to listen on port ${SSH_PORT}…"
# remove any existing Port lines
sed -i '/^\s*#\?\s*Port\s\+[0-9]\+/d' "$SSH_CFG"
# add ours at the top
sed -i "1iPort ${SSH_PORT}" "$SSH_CFG"

# ensure binding on all interfaces
if ! grep -q '^ListenAddress' "$SSH_CFG"; then
  echo 'ListenAddress 0.0.0.0' >> "$SSH_CFG"
fi

# restart (or start) and enable the SSH service
systemctl restart ssh
systemctl enable  ssh

### 8. Configure unattended-upgrades
echo "→ Configuring automatic security updates…"
dpkg-reconfigure --frontend=noninteractive unattended-upgrades
if [[ -n "$ADMIN_EMAIL" ]]; then
  APT_CONF=/etc/apt/apt.conf.d/50unattended-upgrades
  sed -i 's|^//\s*Unattended-Upgrade::Mail.*|Unattended-Upgrade::Mail "'"$ADMIN_EMAIL"'" ;|' "$APT_CONF" \
    || echo "Unattended-Upgrade::Mail \"$ADMIN_EMAIL\";" >> "$APT_CONF"
  echo "   Reports will be mailed to $ADMIN_EMAIL"
fi

### 9. Configure Fail2Ban for SSH
echo "→ Configuring Fail2Ban for SSH…"
cat <<EOF > /etc/fail2ban/jail.d/ssh.local
[sshd]
enabled   = true
port      = ${SSH_PORT}
maxretry  = 5
bantime   = 3600
findtime  = 600
EOF
systemctl restart fail2ban

### 10. Install Docker & docker-compose (v1)
echo "→ Installing Docker Engine and docker-compose (v1)…"
apt update
apt install -y docker.io docker-compose

echo "→ Enabling and starting Docker service…"
systemctl enable --now docker

echo "→ Verifying installation…"
docker --version           # e.g. Docker version 26.x.x
docker-compose --version   # e.g. docker-compose version 1.x.x

### Done
echo "✅ Setup complete!"
echo "   • SSH as '$NEW_USER': ssh -p ${SSH_PORT} ${NEW_USER}@<server-ip>"
echo "   • Then escalate: sudo -i"