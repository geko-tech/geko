#!/usr/bin/env bash

PROJECT_DESCRIPTION_BASE_URL=$(grep -E 'url: ".*/ProjectDescription(\.git)?", branch: "' Package.swift | sed -nE 's|.*url: "(.*)/ProjectDescription(\.git)?".*|\1|p')
PROJECT_DESCRIPTION_VERSION=$(grep -E 'url: ".*/ProjectDescription(\.git)?", branch: "' Package.swift | sed -n 's/.*branch: "\([^"]*\)".*/\1/p')
if [ -z "$PROJECT_DESCRIPTION_VERSION" ]; then
    echo "Error: PROJECT_DESCRIPTION_VERSION not found"
    exit 1
fi
git clone --depth 1 --branch $PROJECT_DESCRIPTION_VERSION "$PROJECT_DESCRIPTION_BASE_URL/ProjectDescription"
