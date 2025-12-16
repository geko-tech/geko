#!/usr/bin/env bash

# TODO: Github fix url after setup
PROJECT_DESCRIPTION_VERSION=$(grep 'url: "replace_me", branch: "' Package.swift | sed -n 's/.*branch: "\([^"]*\)".*/\1/p')
if [ -z "$PROJECT_DESCRIPTION_VERSION" ]; then
    echo "Error: PROJECT_DESCRIPTION_VERSION not found"
    exit 1
fi
git clone --depth 1 --branch $PROJECT_DESCRIPTION_VERSION "replace_me"
