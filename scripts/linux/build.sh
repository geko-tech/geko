#!/usr/bin/bash

set -eo pipefail

GEKO_SWIFT_VERSION_FILE="Sources/GekoSupport/Constants.swift"
UTILITY_NAME=""
BUMP_TYPE=""

while getopts "n:b:" flag; do
	case "$flag" in
	n) UTILITY_NAME="$OPTARG" ;;
	b) BUMP_TYPE="$OPTARG" ;;
	*) exit 1 ;;
	esac
done

set_is_stage() {
	sed -Ei 's/let isStage = (true|false)/let isStage = '"$1"'/' $GEKO_SWIFT_VERSION_FILE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$BUMP_TYPE" == "none" ]]; then
	NEW_VERSION=$($SCRIPT_DIR/new_version_number.sh -n $UTILITY_NAME -b $BUMP_TYPE -a $CI_COMMIT_SHORT_SHA)
else
	set_is_stage "false"
	NEW_VERSION=$($SCRIPT_DIR/new_version_number.sh -n $UTILITY_NAME -b $BUMP_TYPE)
fi

$SCRIPT_DIR/build_linux.sh

set_is_stage "true"

echo $NEW_VERSION > version.txt
