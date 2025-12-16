#!/usr/bin/env bash

set -eo pipefail

if (( $# != 2 )); then
  >&2 echo -e "\033[31m⛔️ Pass module name and output folder path.\033[0m"
  exit 1
fi

MODULE_NAME=$1
OUTPUT_FOLDER=$2

# Checkout the latest version.
DOCS_VERSION=$(bundle exec ruby scripts/latest_versions.rb 1)

# Build DocC.
scripts/build_docc.sh $MODULE_NAME $OUTPUT_FOLDER "/geko" Geko/Release/$DOCS_VERSION
du -sh $OUTPUT_FOLDER | cut -f1
