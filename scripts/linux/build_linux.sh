#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR=$($SCRIPT_DIR/../../make/utilities/root_dir.sh)
BUILD_DIR="$ROOT_DIR/build"

swift build \
	--product geko \
	-c release \
	-Xlinker -rpath \
	-Xlinker @executable_path

cd .build/release

$ROOT_DIR/scripts/generate_geko_source.sh geko_source.json $GEKO_LINUX_AUTOUPDATE_SOURCE

rm -rf $BUILD_DIR
mkdir $BUILD_DIR

tar -czf "$BUILD_DIR/geko_linux_$(uname -m).tgz" \
	geko \
	libProjectDescription.so \
	Modules/ProjectDescription.swiftmodule \
	Modules/ProjectDescription.swiftinterface \
	Modules/ProjectDescription.private.swiftinterface \
	Modules/ProjectDescription.swiftdoc \
	Modules/ProjectDescription.abi.json \
	geko_source.json
