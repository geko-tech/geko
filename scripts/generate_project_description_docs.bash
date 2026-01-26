# !/bin/bash

if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    PD_DOCS="$GITHUB_WORKSPACE"/docs/projectdescription
else
    PD_DOCS=$PWD/docs/projectdescription
fi

# Clone ProjectDescription with current version
PROJECT_PATH=$PWD
TMP_DIR_PD=$(mktemp -d)

PROJECT_DESCRIPTION_VERSION=$(sed -n 's/.*branch: *"\([^"]*\)".*/\1/p' Package.swift)
git clone --depth 1 --branch $PROJECT_DESCRIPTION_VERSION "https://github.com/geko-tech/project-description.git" $TMP_DIR_PD
cd $TMP_DIR_PD
swift build

# Download forked build of SourceDocs
TMP_DIR=$(mktemp -d)
curl -L https://github.com/geko-tech/SourceDocs/releases/download/2.0.2/sourcedocs.macos.zip -o $TMP_DIR/sourcedocs.zip
unzip -o "$TMP_DIR/sourcedocs.zip" -d "$TMP_DIR"
SOURCEDOCS=$(find $TMP_DIR -type f -name "sourcedocs")

# Generate markdown public api
"$SOURCEDOCS" generate --spm-module ProjectDescription -o $PD_DOCS --table-of-contents --clean

# Cleanup
rm -rf "$TEMP_DIR"
rm -rf "$TMP_DIR_PD"
rm $PD_DOCS/README.md
