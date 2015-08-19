#!/bin/bash

if ! [ -d "$siesta_dir" ]; then
    echo "\$siesta_dir does not exist or is not executable"
    exit 1
fi

docs_dir=$(dirname "$(dirname "$0")")

echo "Building user guide in $docs_dir ..."

for src in "$siesta_dir"/{README,Docs/*}.md; do
    dst="${src##"$siesta_dir"}"
    dst="${dst%.md}"
    dst=$(echo $dst | perl -pe 's/README/index/' | perl -pe 's/Docs/guide/' | perl -pe 's/index$//')
    title=$(egrep '^# ' "$src" | head -1 | perl -pe 's/^#* *//' | perl -pe 's/^Siesta$/Overview/')
    echo "Generating $dst ($title)"
    mkdir -p "./$dst"
    (
        echo "---"
        echo "title: '$title'"
        echo "layout: default"
        echo "---"
        echo
        cat "$src" | perl -pe 's/\]\(([^\]]+)\.md\)/]($1)/g'
    ) > "$docs_dir/$dst/index.md"

    cp -R "$siesta_dir"/Docs/images "$docs_dir"/guide/
done
