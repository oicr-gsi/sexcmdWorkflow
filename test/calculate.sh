#! /usr/bin/env bash
cd $1
grep ^Sex_Determination *.report | sed 's!/.*/!!' | sed 's/.*Sex/Sex/' | md5sum
