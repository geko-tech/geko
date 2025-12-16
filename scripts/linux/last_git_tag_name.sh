#!/usr/bin/env bash

# Example: ./scripts/linux/last_git_tag_name.sh Geko@*

TAG_MATCH_PATTERN=$1

HASH=$(git rev-list --tags=$TAG_MATCH_PATTERN --max-count=1)

git describe --tags $HASH --match $TAG_MATCH_PATTERN
