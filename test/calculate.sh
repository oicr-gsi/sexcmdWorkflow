#! /usr/bin/env bash
cd $1
cat *.OUTPUT  | md5sum
