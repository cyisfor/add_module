#!/bin/sh
cd add_module
git pull
cd ..
git add add_module
exec git commit -m "Updating add_module"
