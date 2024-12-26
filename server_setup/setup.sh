#!/usr/bin/env bash
####################################################
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <https://unlicense.org>
#
# Created by JB Stepan <jbstepan.com>
####################################################

username="" # Required
password="" # Required
ssh_key="" # Required
install_docker=true
firewall_enable=true
ufw_allowed=(22, 80, 443)
addtional_packages=(vim)
remove_packages=(nano)
timezone="Etc/UTC"

####################################################

BLUE='\033[0;34m'
NC='\033[0m'

createUser() {
  printf "${BLUE} [!] Creating user account 🧑...${NC}\n"

  useradd -m -U -s /bin/bash -G sudo $username
  echo $username:$password | chpasswd
}

packages() {
  printf "${BLUE} [!] Updating system ⬆️...${NC}\n"
  apt -y update && apt upgrade 

  printf "${BLUE} [!] Installing packages 📦...${NC}\n"
  pkgs=(fail2ban ufw curl)
  apt -y --ignore-missing install "${pkgs[@]}" 
  apt -y --ignore-missing install "${addtional_packages[@]}" 

  printf "${BLUE} [!] Removing packages ❌...${NC}\n"
  apt -y --ignore-missing remove "${remove_packages[@]}"

  if ["$install_docker" = true] ; then
    # Add Docker's official GPG key:
    printf "${BLUE} [!] Installing Docker 🐳...${NC}\n"
    apt-get update
    apt-get install ca-certificates curl -y
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update

    apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
  fi
}

firewall() {
  printf "${BLUE} [!]Configuring firewall 🔥...${NC}\n"
  for i in "${ufw_allowed[@]}"; do
    echo "$i"
  done
  sudo ufw enable
}

ssh() {
  printf "${BLUE} [!] Configuring SSH 🐚...${NC}\n"
  # Change someconfig in SSH
  sed -i -e '/^\(#\|\)PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)KbdInteractiveAuthentication/s/^.*$/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)ChallengeResponseAuthentication/s/^.*$/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
  sed -i -e '/^\(#\|\)AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config

  mkdir /home/$username/.ssh

  touch /home/$username/.ssh/authorized_keys

  echo $ssh_key > /home/$username/.ssh/authorized_keys

  sshd -t
  sudo systemctl restart sshd
}

misc() {
  timedatectl set-timezone ${timezone}
}

main() {
  createUser
  packages
  if ["$firewall_enable" = true] ; then
    firewall
  fi
  ssh
  misc

  printf "${BLUE} [!] Script finished ✅.${NC}\n"
}

main