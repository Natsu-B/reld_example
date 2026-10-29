#!/bin/sh

cd reld
files=(*)
if [ ${#files[@]} -eq 0 ]; then
    echo "Error: Directory is empty! try running `git submodule update --init --recursive`..."
    exit 1
fi

cargo build