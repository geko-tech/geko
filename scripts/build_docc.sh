#!/usr/bin/env bash

set -eo pipefail

if (( $# != 4 )); then
  >&2 echo -e "\033[31m⛔️ Pass module name, output folder path, hosting base path and git tag or branch.\033[0m"
  exit 1
fi

MODULE_NAME=$1        # ProjectDescription
OUTPUT_FOLDER_PATH=$2 # Sources/ProjectDescription/docc
HOSTING_BASE_PATH=$3  # /geko
GIT_BRANCH_OR_TAG=$4  # master

echo -e "\033[0;36m> Cloning $MODULE_NAME\033[0m"

chmod +x scripts/clone_project_description_repo.bash
scripts/clone_project_description_repo.bash
cd project-description

echo -e "\033[0;36m> Building documentation for $MODULE_NAME\033[0m"
rm -rf $OUTPUT_FOLDER_PATH

swift package --allow-writing-to-directory $OUTPUT_FOLDER_PATH \
  generate-documentation \
  --target $MODULE_NAME \
  --output-path $OUTPUT_FOLDER_PATH \
  --transform-for-static-hosting \
  --hosting-base-path $HOSTING_BASE_PATH \
  --source-service gitlab \
  # TODO: Github fix url after setup
  --source-service-base-url "" \
  --checkout-path $PWD | xcbeautify | tee /dev/null

# This will redirect the root page to the documentation
MODULE_NAME_LOWERCASE=`echo "${MODULE_NAME}" | tr '[:upper:]' '[:lower:]'`
echo "<script>window.location.href += \"documentation/${MODULE_NAME_LOWERCASE}\"</script>" > "${OUTPUT_FOLDER_PATH}/index.html"

cd ..
mv project-description/$OUTPUT_FOLDER_PATH $OUTPUT_FOLDER_PATH
