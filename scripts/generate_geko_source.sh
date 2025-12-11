#!/bin/bash

set -e

if (( $# != 2 )); then
	echo "Usage: generate_geko_source.sh output_file_name https://example.com/geko_{version}_{arch}_{platform}.zip"
	exit 1
fi

OUTPUT_FILE=$1
URL_TEMPLATE=$2

echo "{\"url\":\"$URL_TEMPLATE\"}" > $OUTPUT_FILE
