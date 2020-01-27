#!/bin/sh
set -e
cd add_module
git pull
cd ..
git add add_module
git commit -m "Updating add_module"
git show
