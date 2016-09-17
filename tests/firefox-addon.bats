#!/usr/bin/env bats

load 'bats-ansible/load'

@test "Module syntax" {
    bash -n ${BATS_TEST_DIRNAME}/../library/firefox_addon 
}
