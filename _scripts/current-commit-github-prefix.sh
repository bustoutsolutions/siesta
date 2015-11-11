#!/bin/bash

echo -n "https://github.com/bustoutsolutions/siesta/blob/"
git --git-dir "$siesta_dir/.git" describe --abbrev=0 --tags --exact-match 2>/dev/null ||
git --git-dir "$siesta_dir/.git" rev-parse HEAD
