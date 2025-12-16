#!/usr/bin/env bash

GEKO_SWIFT_VERSION_FILE="Sources/GekoSupport/Constants.swift"

[[ "$(uname)" == "Darwin" ]] && sed_cmd=(sed -i '' -E) || sed_cmd=(sed -Ei)

"${sed_cmd[@]}" 's/let isStage = (true|false)/let isStage = '"$1"'/' $GEKO_SWIFT_VERSION_FILE
