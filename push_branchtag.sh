#!/bin/sh
if [[ -z "$1" ]]; then
	echo specify branch tag please
	exit 1
fi
git branch -f $1
git push repo $1
