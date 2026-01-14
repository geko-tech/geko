#!/usr/bin/env bash

set -eo pipefail

UTILITY_NAME=""
BUMP_TYPE=""
COMMIT_HASH=""

while getopts "n:b:h:" flag; do
	case "$flag" in
	n) UTILITY_NAME="$OPTARG" ;;
	b) BUMP_TYPE="$OPTARG" ;;
	h) COMMIT_HASH="$OPTARG" ;;
	*) exit 1 ;;
	esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$BUMP_TYPE" == "none" ]]; then
	NEW_VERSION=$($SCRIPT_DIR/new_version_number.sh -n "$UTILITY_NAME" -b "$BUMP_TYPE" -a "$COMMIT_HASH")
else
	$SCRIPT_DIR/../set_is_stage.sh "false"
	NEW_VERSION=$($SCRIPT_DIR/new_version_number.sh -n "$UTILITY_NAME" -b "$BUMP_TYPE")
fi

ROOT_DIR=$($SCRIPT_DIR/../../make/utilities/root_dir.sh)

if [[ "$(uname)" == "Darwin" ]]; then
	$ROOT_DIR/make/tasks/workspace/release/bundle.sh
else
	$SCRIPT_DIR/build_linux.sh
fi

$SCRIPT_DIR/../set_is_stage.sh "true"

echo $NEW_VERSION > version.txt
