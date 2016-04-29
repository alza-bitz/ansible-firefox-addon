#!/usr/bin/env bats

# testing requirements: docker, ansible

# https://github.com/tutumcloud/tutum-fedora
readonly docker_image="tutum/fedora:21"
readonly docker_container_name="ansible-firefox-addon"
readonly addon_url=https://addons.mozilla.org/en-US/firefox/addon/adblock-plus

docker_exec() {
  docker exec $docker_container_name $@ > /dev/null
}

docker_exec_d() {
  docker exec -d $docker_container_name $@ > /dev/null
}

docker_exec_sh() {
  # workaround for https://github.com/sstephenson/bats/issues/89
  local IFS=' '
  docker exec $docker_container_name sh -c "$*" > /dev/null
}

ansible_exec_module() {
  local _name=$1
  local _args=$2
  ANSIBLE_LIBRARY=../ ansible localhost -i hosts -u root -m $_name ${_args:+-a "$_args"}
}

setup() {
  local _ssh_public_key=~/.ssh/id_rsa.pub
  docker run --name $docker_container_name -d -p 5555:22 -e AUTHORIZED_KEYS="$(< $_ssh_public_key)" -v $docker_container_name:/var/cache/yum/x86_64/21/ $docker_image
  docker_exec sed -i -e 's/keepcache=\(.*\)/keepcache=1/' /etc/yum.conf
  docker_exec yum -y install deltarpm xorg-x11-server-Xvfb
  docker_exec_d Xvfb :1
}

@test "Module exec with url arg missing" {
  run ansible_exec_module firefox_addon
  [[ $output =~ "missing required arguments: url" ]]
}

@test "Module exec with state arg having invalid value" {
  run ansible_exec_module firefox_addon "url=$addon_url state=latest"
  [[ $output =~ "value of state must be one of: present,absent, got: latest" ]]
}

@test "Module exec with state arg having default value of present" {
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$addon_url display=:1"
  [[ $output =~ changed.*true ]]
  docker_exec_sh test -d "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with state present" {
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$addon_url state=present display=:1"
  [[ $output =~ changed.*true ]]
}

@test "Module exec with state absent" {
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$addon_url state=absent display=:1"
  [[ $output =~ changed.*false ]]
}

@test "Module exec with state absent and addon already installed" {
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$addon_url state=present display=:1"
  [[ $output =~ changed.*true ]]
  run ansible_exec_module firefox_addon "url=$addon_url state=absent display=:1"
  [[ $output =~ changed.*true ]]
  docker_exec_sh test ! -e "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with state present twice and check idempotent" {
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$addon_url display=:1"
  run ansible_exec_module firefox_addon "url=$addon_url display=:1"
  [[ $output =~ changed.*false ]]
}

@test "Module exec with complete theme addon and check selected skin pref" {
  local _addon_url=https://addons.mozilla.org/en-US/firefox/addon/fxchrome
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$_addon_url display=:1"
  [[ $output =~ changed.*true ]]
  docker_exec_sh grep FXChrome "~/.mozilla/firefox/*.default/user.js"
}

@test "Module exec with display arg missing when there is no DISPLAY environment" {
  docker_exec yum -y install firefox unzip curl
  run ansible_exec_module firefox_addon "url=$addon_url"
  [[ $output =~ 'Error: no display specified' ]]
}

teardown() {
  docker stop $docker_container_name > /dev/null
  docker rm $docker_container_name > /dev/null
}
