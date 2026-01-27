#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR=$($SCRIPT_DIR/../../../utilities/root_dir.sh)
source $ROOT_DIR/make/utilities/setup.sh
XCODE_PATH_SCRIPT_PATH=$SCRIPT_DIR/../../../utilities/xcode_path.sh
BUILD_DIRECTORY=$ROOT_DIR/build
# Xcode 15 has a bug that causes the /var/folders... temporary directory, which is a symlink to
# /private/var/folders to crash Xcode.
TMP_DIR=/private$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT # Ensures it gets deleted
CLONED_SOURCE_PACKAGES=$TMP_DIR/clonedSourcePackages
XCODE_VERSION=$(cat $ROOT_DIR/.xcode-version)
LIBRARIES_XCODE_VERSION=$(cat $ROOT_DIR/.xcode-version-libraries)
BUILD_DIR=$ROOT_DIR/build

echo "$(format_section "Building release into $BUILD_DIRECTORY")"

rm -rf $ROOT_DIR/Geko.xcodeproj
rm -rf $ROOT_DIR/Geko.xcworkspace
rm -rf $BUILD_DIRECTORY
mkdir -p $BUILD_DIRECTORY

build_fat_release_project_description() {
    (
    cd $CLONED_SOURCE_PACKAGES/checkouts/ProjectDescription

    PROJECT_DESCRIPTION="project-description"
    PROJ_DESC_BUILD_DIR=$TMP_DIR/$PROJECT_DESCRIPTION

    xcrun xcodebuild -scheme $PROJECT_DESCRIPTION -configuration Release -destination "generic/platform=macOS" BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS='arm64 x86_64' BUILD_DIR=$PROJ_DESC_BUILD_DIR clean build

    # We remove the PRODUCT.swiftmodule/Project directory because
    # this directory contains objects that are not stable across Swift releases.
    rm -rf $PROJ_DESC_BUILD_DIR/Release/$PROJECT_DESCRIPTION.swiftmodule/Project
    cp -a $PROJ_DESC_BUILD_DIR/Release/PackageFrameworks/$PROJECT_DESCRIPTION.framework $BUILD_DIRECTORY/$PROJECT_DESCRIPTION.framework
    mkdir -p $BUILD_DIRECTORY/$PROJECT_DESCRIPTION.framework/Modules
    cp -a $PROJ_DESC_BUILD_DIR/Release/$PROJECT_DESCRIPTION.swiftmodule $BUILD_DIRECTORY/$PROJECT_DESCRIPTION.framework/Modules/$PROJECT_DESCRIPTION.swiftmodule
    cp -a $PROJ_DESC_BUILD_DIR/Release/$PROJECT_DESCRIPTION.framework.dSYM $BUILD_DIRECTORY/$PROJECT_DESCRIPTION.framework.dSYM
    )
}

build_fat_release_binary() {
    (
    cd $ROOT_DIR || exit 1

    xcrun xcodebuild -scheme $1 -configuration Release -destination "generic/platform=macOS" -clonedSourcePackagesDirPath $CLONED_SOURCE_PACKAGES ARCHS='arm64 x86_64' OTHER_LDFLAGS="-rpath @executable_path" BUILD_DIR=$TMP_DIR/$1 -quiet clean build

    cp -a $TMP_DIR/$1/Release/$1 $BUILD_DIRECTORY/$1
    )
}

echo "$(format_section "Resolving Package Dependencies")"

xcrun xcodebuild -resolvePackageDependencies -clonedSourcePackagesDirPath $CLONED_SOURCE_PACKAGES

echo "$(format_section "Building")"

echo "$(format_subsection "Building project-description framework")"
build_fat_release_project_description

echo "$(format_subsection "Building geko executable")"
build_fat_release_binary "geko"

echo "$(format_section "Copying assets")"

echo "$(format_subsection "Copying Geko's templates")"
cp -r $ROOT_DIR/Templates $BUILD_DIRECTORY/Templates

echo "$(format_subsection "Copy Swift libraries into the Geko binary")"

swift stdlib-tool --copy --scan-executable $BUILD_DIRECTORY/geko --platform macosx --destination $BUILD_DIRECTORY

echo "$(format_subsection "Generate geko_source.json into the Geko bundle")"
$ROOT_DIR/scripts/generate_geko_source.sh $BUILD_DIRECTORY/geko_source.json $GEKO_MACOS_AUTOUPDATE_SOURCE

echo "$(format_section "Bundling")"

(
    cd $BUILD_DIRECTORY || exit 1
    echo "$(format_subsection "Bundling geko_macos.zip")"
    zip -q -r --symlinks geko_macos.zip geko libswift_Concurrency.dylib ProjectDescription.framework ProjectDescription.framework.dSYM Templates vendor geko_source.json
    echo "$(format_subsection "Bundling ProjectDescription.framework.zip")"
    zip -q -r --symlinks ProjectDescription.framework.zip ProjectDescription.framework ProjectDescription.framework.dSYM

    rm -rf geko ProjectDescription.framework ProjectDescription.framework.dSYM Templates vendor

    : > SHASUMS256.txt
    : > SHASUMS512.txt

    for file in *; do
        if [ -f "$file" ]; then
            if [[ "$file" == "SHASUMS256.txt" || "$file" == "SHASUMS512.txt" ]]; then
                continue
            fi
            echo "$(shasum -a 256 "$file" | awk '{print $1}') ./$file" >> SHASUMS256.txt
            echo "$(shasum -a 512 "$file" | awk '{print $1}') ./$file" >> SHASUMS512.txt
        fi
    done
)
