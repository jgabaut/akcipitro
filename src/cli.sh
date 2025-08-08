#!/bin/bash

flat="$(./src/flatten.awk "$@")"
[[ $? -eq 0 ]] || {
    printf "Failed flattening input\n"
    exit 1
}
"./src/core.awk" <<<"$flat"
