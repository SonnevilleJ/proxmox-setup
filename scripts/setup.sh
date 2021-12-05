#!/usr/bin/env bash

OS_CODENAME="$(grep "VERSION_CODENAME=" /etc/os-release | cut -d"=" -f 2 | xargs)"

# disable enterprise proxmox repo
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
  sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
fi
# enable free public proxmox repo
if [ ! -f /etc/apt/sources.list.d/proxmox.list ] && [ ! -f /etc/apt/sources.list.d/pve-public-repo.list ] && [ ! -f /etc/apt/sources.list.d/pve-install-repo.list ]; then
  echo -e "deb http://download.proxmox.com/debian/pve ${OS_CODENAME} pve-no-subscription\\n" >/etc/apt/sources.list.d/pve-public-repo.list
fi

# rebuild and add non-free to /etc/apt/sources.list
cat <<EOF >/etc/apt/sources.list
deb https://ftp.debian.org/debian ${OS_CODENAME} main contrib
deb https://ftp.debian.org/debian ${OS_CODENAME}-updates main contrib
# non-free
#deb https://httpredir.debian.org/debian/ ${OS_CODENAME} main contrib non-free
# security updates
deb https://security.debian.org/debian-security ${OS_CODENAME}-security/updates main contrib
EOF

# Refresh the package lists
apt-get update >/dev/null 2>&1

# Remove conflicting utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' purge ntp openntpd chrony

# Fixes for common apt repo errors
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install apt-transport-https debian-archive-keyring ca-certificates curl

# update proxmox and install various system utils
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' dist-upgrade
pveam update

# apt autoremove and autoclean
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install autoremove autoclean

## Install zfs-auto-snapshot
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install zfs-auto-snapshot
# make 5min snapshots , keep 12 5min snapshots
if [ -f "/etc/cron.d/zfs-auto-snapshot" ]; then
  sed -i 's|--keep=[0-9]*|--keep=12|g' /etc/cron.d/zfs-auto-snapshot
  sed -i 's|*/[0-9]*|*/5|g' /etc/cron.d/zfs-auto-snapshot
fi
# keep 24 hourly snapshots
if [ -f "/etc/cron.hourly/zfs-auto-snapshot" ]; then
  sed -i 's|--keep=[0-9]*|--keep=24|g' /etc/cron.hourly/zfs-auto-snapshot
fi
# keep 7 daily snapshots
if [ -f "/etc/cron.daily/zfs-auto-snapshot" ]; then
  sed -i 's|--keep=[0-9]*|--keep=7|g' /etc/cron.daily/zfs-auto-snapshot
fi
# keep 4 weekly snapshots
if [ -f "/etc/cron.weekly/zfs-auto-snapshot" ]; then
  sed -i 's|--keep=[0-9]*|--keep=4|g' /etc/cron.weekly/zfs-auto-snapshot
fi
# keep 3 monthly snapshots
if [ -f "/etc/cron.monthly/zfs-auto-snapshot" ]; then
  sed -i 's|--keep=[0-9]*|--keep=3|g' /etc/cron.monthly/zfs-auto-snapshot
fi

## Automatically Synchronize the time
cat <<EOF >/etc/systemd/timesyncd.conf
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
service systemd-timesyncd start
timedatectl set-ntp true

