#!/usr/bin/env bats

# testing requirements: docker, ansible, xargs

# https://github.com/tutumcloud/tutum-fedora
readonly DOCKER_IMAGE="tutum/fedora:21"
readonly SSH_PUBLIC_KEY_FILE=~/.ssh/id_rsa.pub
readonly DOCKER_CONTAINER_NAME="ansible-firefox-test"

docker_exec() {
  docker exec $DOCKER_CONTAINER_NAME $@ > /dev/null
}

ansible_exec() {
  ANSIBLE_LIBRARY=../ ansible "$@"
}

setup() {
  docker ps -q -f name=$DOCKER_CONTAINER_NAME | xargs -r docker stop > /dev/null
  docker ps -aq -f name=$DOCKER_CONTAINER_NAME | xargs -r docker rm > /dev/null
  docker run --name $DOCKER_CONTAINER_NAME -d -p 5555:22 -e AUTHORIZED_KEYS="$(< $SSH_PUBLIC_KEY_FILE)" $DOCKER_IMAGE
}

@test "Module exec with url arg missing" {
  run ansible_exec localhost -i hosts -u root -m firefox_addon
  [[ $output =~ "missing required arguments: url" ]]
}

@test "Module exec with state arg having invalid value" {
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi state=latest'
  [[ $output =~ "value of state must be one of: present,absent, got: latest" ]]
}

@test "Module exec with state arg having default value of present" {
  docker_exec yum -y install firefox
  docker_exec yum -y install unzip curl
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi'
  printf "output was: $output\n"
  [[ $output =~ changed.*true ]]
  docker_exec test -d "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with state present" {
  docker_exec yum -y install firefox
  docker_exec yum -y install unzip curl
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi state=present'
  [[ $output =~ changed.*true ]]
}

@test "Module exec with state absent" {
  docker_exec yum -y install unzip curl
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi state=absent'
  [[ $output =~ changed.*false ]]
}

@test "Module exec with state absent and addon already installed" {
  docker_exec yum -y install firefox
  docker_exec yum -y install unzip curl
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi state=present'
  [[ $output =~ changed.*true ]]
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi state=absent'  
  [[ $output =~ changed.*true ]]
  docker_exec test ! -e "/usr/lib64/firefox/browser/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
}

@test "Module exec with state present twice and check idempotent" {
  skip
  docker_exec yum -y install firefox
  docker_exec yum -y install unzip curl
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi'
  run ansible_exec localhost -i hosts -u root -m firefox_addon -a 'url=https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi'
  [[ $output =~ changed.*false ]]
}

teardown() {
  docker stop $DOCKER_CONTAINER_NAME > /dev/null
  docker rm $DOCKER_CONTAINER_NAME > /dev/null
}
