#!/bin/bash
if [[ -n "$branch" ]]; then
	:
elif [[ -z "$1" ]]; then
	git branch
	echo specify branch please
	read branch
else
	branch=$1
fi
cd add_module
git pull
cd ..
git add add_module
git commit -m "Updating add_module"
git push
( . ./add_module/push_branchtag.sh $branch )
git show
