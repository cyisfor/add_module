#!/bin/sh
if [[ -z "$1" ]]; then
	echo specify branch please
	exit 1
fi
git branch -d $1
git branch $1
git push repo $1
