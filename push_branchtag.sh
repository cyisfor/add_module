#!/bin/sh
if [[ -z "$1" ]]; then
	git branch
	echo specify branch please
	read branch
else
	branch=$1
fi

git branch -f $branch
git push -u repo $branch
