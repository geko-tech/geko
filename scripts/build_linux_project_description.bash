#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR=$($SCRIPT_DIR/../make/utilities/root_dir.sh)
BUILD_DIR="$ROOT_DIR/build"

chmod +x scripts/clone_project_description_repo.bash
scripts/clone_project_description_repo.bash
cd project-description
swift build --package-path . --product ProjectDescription -c release

rm -rf $BUILD_DIR
mkdir $BUILD_DIR

ARTIFACT_PATH=$BUILD_DIR/ProjectDescription.tgz
tar -czf $ARTIFACT_PATH -C .build/release/ libProjectDescription.so -C Modules ProjectDescription.swiftmodule
