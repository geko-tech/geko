#!/usr/bin/env bash

set -eo pipefail

git fetch --tags
LAST_VERSION=$(git describe --abbrev=0 --tags --match 'Geko/Release/*' | awk -F/ '{print $3}')

if [ -n "$LAST_VERSION" ]; then
    s3cmd --host=$UPLOAD_TO_S3_ENDPOINT --host-bucket=$HOST_BUCKET --access_key=$UPLOAD_TO_S3_ACCESS_KEY --secret_key=$UPLOAD_TO_S3_SECRET_KEY put build/ProjectDescription.tgz s3://$UPLOAD_TO_S3_BUCKET/ProjectDescription/linux/amd64/swift-6.1.2/$LAST_VERSION/ProjectDescription.tgz
fi
s3cmd --host=$UPLOAD_TO_S3_ENDPOINT --host-bucket=$HOST_BUCKET --access_key=$UPLOAD_TO_S3_ACCESS_KEY --secret_key=$UPLOAD_TO_S3_SECRET_KEY put build/ProjectDescription.tgz s3://$UPLOAD_TO_S3_BUCKET/ProjectDescription/linux/latest/ProjectDescription.tgz
