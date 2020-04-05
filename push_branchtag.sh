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

git branch -f $branch
git push -u repo $branch
