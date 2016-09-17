#!/usr/bin/env bats

# dependencies of this test: bats, ansible, docker
# control machine requirements for module under test: ???

load 'bats-ansible/load'

readonly addon_url=https://addons.mozilla.org/en-US/firefox/addon/adblock-plus

setup() {
  container=$(container_startup fedora)
  hosts=$(tmp_file $(container_inventory $container))
  container_dnf_conf $container keepcache 1
  container_dnf_conf $container metadata_timer_sync 0
  container_exec_sudo $container dnf -q -y install xorg-x11-server-Xvfb daemonize
  container_exec_sudo $container daemonize /usr/bin/Xvfb :1
}

@test "Module exec with url arg missing" {
  run container_exec_module $container firefox_addon
  [[ $output =~ "missing required arguments: url" ]]
}

@test "Module exec with state arg having invalid value" {
  run container_exec_module $container firefox_addon "url=$addon_url state=latest"
  [[ $output =~ "value of state must be one of: present,absent, got: latest" ]]
}

@test "Module exec with state arg having default value of present" {
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$addon_url display=:1"
  [[ $output =~ SUCCESS.*changed.*true ]]
  container_exec $container test -d "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with xpi url instead of page url" {
  local _addon_url=https://addons.mozilla.org/firefox/downloads/latest/adblock-plus/addon-1865-latest.xpi
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$_addon_url display=:1"
  [[ $output =~ SUCCESS.*changed.*true ]]
  container_exec $container test -d "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with state present" {
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$addon_url state=present display=:1"
  [[ $output =~ SUCCESS.*changed.*true ]]
}

@test "Module exec with state absent" {
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$addon_url state=absent display=:1"
  [[ $output =~ SUCCESS.*changed.*false ]]
}

@test "Module exec with state absent and addon already installed" {
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$addon_url state=present display=:1"
  [[ $output =~ SUCCESS.*changed.*true ]]
  run container_exec_module $container firefox_addon "url=$addon_url state=absent display=:1"
  [[ $output =~ SUCCESS.*changed.*true ]]
  container_exec $container test ! -e "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with state present twice and check idempotent" {
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$addon_url display=:1"
  run container_exec_module $container firefox_addon "url=$addon_url display=:1"
  [[ $output =~ SUCCESS.*changed.*false ]]
}

@test "Module exec with complete theme addon and check selected skin pref" {
  local _addon_url=https://addons.mozilla.org/en-US/firefox/addon/fxchrome
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$_addon_url display=:1"
  [[ $output =~ SUCCESS.*changed.*true ]]
  container_exec $container grep FXChrome "~/.mozilla/firefox/*.default/user.js"
}

@test "Module exec with display arg missing when there is no DISPLAY environment" {
  container_exec_sudo $container dnf -q -y install firefox unzip
  run container_exec_module $container firefox_addon "url=$addon_url"
  [[ $output =~ 'Error: GDK_BACKEND does not match available displays' ]]
}

teardown() {
  container_cleanup
}
