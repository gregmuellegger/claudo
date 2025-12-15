#!/bin/bash

sudo apt-get update && sudo apt-get install -y asciinema fonts-dejavu

# Install agg (asciinema gif generator)
curl -sL https://github.com/asciinema/agg/releases/download/v1.7.0/agg-x86_64-unknown-linux-gnu -o ~/.local/bin/agg && chmod +x ~/.local/bin/agg

echo "postCreate.sh successful"

if [ -e .devcontainer/postCreate.local.sh ] ; then
    echo "Running postCreate.local.sh"
    .devcontainer/postCreate.local.sh
fi
