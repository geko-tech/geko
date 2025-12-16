#!/usr/bin/env bash

UTILITY_NAME=""
BUMP_TYPE=""
ALPHA=""

GEKO_SWIFT_VERSION_FILE="Sources/GekoSupport/Constants.swift"

print_usage() {
	cat <<EOF
Example: ./new_version_number.sh -n <utility name> -b <bump type> -a <sha>"
Params:
	-n Utility name
	-b bump_type (major|minor|patch|none)
	-a alpha
EOF
}

bump_version_in_sources() {
	PROJECT_DESCRIPTION_VERSION=$(grep 'url: "https://github.com/geko-tech/ProjectDescription.git", branch: "' Package.swift | sed -n 's/.*branch: "\([^"]*\)".*/\1/p')

	[[ "$(uname)" == "Darwin" ]] && sed_cmd=(sed -i '' -E) || sed_cmd=(sed -Ei)

	"${sed_cmd[@]}" 's/let version = "[0-9.]*"/let version = \"'"$2"'\"/' $1
	"${sed_cmd[@]}" 's!let projectDescriptionVersion = "[a-z, A-Z, 0-9. /]*"!let projectDescriptionVersion = \"'"$PROJECT_DESCRIPTION_VERSION"'\"!' $1
}

while getopts "n:b:a:" flag; do
	case "$flag" in
	n) UTILITY_NAME="$OPTARG" ;;
	b) BUMP_TYPE="$OPTARG" ;;
	a) ALPHA="$OPTARG" ;;
	*)
		print_usage
		exit 1
		;;
	esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LAST_VERSION=$($SCRIPT_DIR/last_utility_version.sh $UTILITY_NAME 2>/dev/null)

LAST_VERSION=${LAST_VERSION:-"0.35.0"}

MAJOR=$(echo $LAST_VERSION | cut -d '.' -f1)
MINOR=$(echo $LAST_VERSION | cut -d '.' -f2)
PATCH=$(echo $LAST_VERSION | cut -d '.' -f3)

case "$BUMP_TYPE" in
major)
	MAJOR=$((MAJOR + 1))
	MINOR=0
	PATCH=0
	;;
minor)
	MINOR=$((MINOR + 1))
	PATCH=0
	;;
patch)
	PATCH=$((PATCH + 1))
	;;
none) ;;
*)
	echo "Unknown bump type: $BUMP_TYPE (use major|minor|patch|none)" >&2
	exit 1
	;;
esac

NEW_VERSION=$(printf '%d.%d.%d\n' "$MAJOR" "$MINOR" "$PATCH")

if [[ -n "$ALPHA" ]]; then
	NEW_VERSION="$NEW_VERSION-$ALPHA"
fi

bump_version_in_sources $GEKO_SWIFT_VERSION_FILE $NEW_VERSION

echo $NEW_VERSION
