#! /usr/bin/env bash
cd $1
tail -n 1 *.OUTPUT  | sed 's!/.*/!!' | sed 's/.*Sex/Sex/' | md5sum
