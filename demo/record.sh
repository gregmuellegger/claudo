#!/bin/bash
set -e

# Function to display and run a command with a pause
run() {
    echo "\$ $*"
    sleep 0.5
    eval "$*"
    sleep 1
}

cd /tmp
rm -rf demo
mkdir demo
cd demo

run '# Install claudo'

# Show shortened URL, run real one
echo '$ curl -fsSL .../claudo -o ~/.local/bin/claudo && chmod +x ~/.local/bin/claudo'
sleep 0.5
curl -fsSL https://raw.githubusercontent.com/gregmuellegger/claudo/main/claudo -o ~/.local/bin/claudo && chmod +x ~/.local/bin/claudo
sleep 1

run 'pwd'
run 'echo "Hey, print your current working directory, \
then create hello.txt with: Hello from claudo!" | \
claudo'

run 'cat hello.txt'
eval "sleep 3"
