#!/usr/bin/env bash

# Function to increment a semantic version string
# Usage: incr_semver <version_string> [major|minor|patch]
IFS=.
parts=($1)
level=$2

# Default to patch if no level specified
[[ -z "$level" ]] && level="patch"

case "$level" in
    major)
        ((parts[0]++))
        parts[1]=0
        parts[2]=0
        ;;
    minor)
        ((parts[1]++))
        parts[2]=0
        ;;
    patch)
        ((parts[2]++))
        ;;
    *)
        echo "Invalid level specified: $level. Use major, minor, or patch." >&2
        return 1
        ;;
esac

echo "${parts[0]}.${parts[1]}.${parts[2]}"