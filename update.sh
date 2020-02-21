#!/bin/sh
set -e
if [[ -z "$1" ]]; then
	echo specify branch please
	exit 1
fi
cd add_module
git pull
cd ..
git add add_module
git commit -m "Updating add_module"
git push
( . ./add_module/push_branchtag.sh $1 )
git show
