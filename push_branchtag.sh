#!/bin/sh
if [[ -z "$1" ]]; then
	echo specify branch tag please
	exec git branch
fi
git branch -f $1
git push -u repo $1
