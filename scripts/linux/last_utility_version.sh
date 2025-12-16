#!/usr/bin/env bash

# Example: ./scripts/linux/last_utility_version.sh Geko

UTILITY_NAME=$1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git fetch --tags --quiet

LAST_TAG=$($SCRIPT_DIR/last_git_tag_name.sh $UTILITY_NAME@*)

if [[ $LAST_TAG =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
	echo ${BASH_REMATCH[1]}
fi
