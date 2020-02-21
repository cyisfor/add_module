#!/bin/sh
set -e
cd add_module
git pull
cd ..
git add add_module
git commit -m "Updating add_module"
git push
( . ./add_module/push_branchtags.sh )
git show
