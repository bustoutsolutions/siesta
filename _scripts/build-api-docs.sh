#!/bin/bash

if ! [ -x "$jazzy_bin" ]; then
    echo "\$jazzy_bin does not exist or is not executable"
    exit 1
fi

if ! [ -d "$siesta_dir" ]; then
    echo "\$siesta_dir does not exist or is not executable"
    exit 1
fi

docs_dir=$(dirname "$(dirname "$0")")

echo "Building docs in $docs_dir ..."

"$jazzy_bin" \
    --clean \
    --source-directory "$siesta_dir" \
    --exclude          "$siesta_dir"/Source/Siesta-ObjC.swift \
    \
    --module Siesta \
    --author 'Bust Out Solutions' \
    --author_url http://bustoutsolutions.com \
    --github_url https://github.com/bustoutsolutions/siesta \
    \
    --categories          "$docs_dir"/_templates/api-categories.yaml \
    --readme              "$docs_dir"/_templates/api-readme.md \
    --template-directory  "$docs_dir"/_templates/jazzy-templates \
    \
    --output              "$docs_dir"/api \
    $jazzy_opts
