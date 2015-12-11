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
    --source-directory   "$siesta_dir" \
    --github-file-prefix "$("$docs_dir"/_scripts/current-commit-github-prefix.sh)" \
    --readme             "$docs_dir"/_templates/api-readme.md \
    --output             "$docs_dir"/api \
    \
    $jazzy_opts
