#!/usr/bin/env bats

# global var
VERBOSE=false
DEBUG=false
FUNC_LIST=()
unset LIB
CUR_NAME=${FUNCNAME[0]}

# load our shell functions and all libs
source $MY_GIT_DIR/shell/lib_shell.sh
source $MY_GIT_DIR/docker/lib_docker.sh
source $MY_GIT_DIR/portainer/lib_portainer.sh

setup() {
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
}

@test "_install_ci" {
  run $MY_GIT_DIR/shell/my_warp.sh -d -v --lib portainer install_ci
  assert_success
}

@test "_container_list" {
  run $MY_GIT_DIR/shell/my_warp.sh -d -v --lib docker container_list
  assert_output --partial "portainerci running"
}