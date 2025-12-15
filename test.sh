#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

echo "=== claudo test suite ==="
echo

# Test: --help
echo "Testing --help..."
./claudo --help | grep -q "Usage:" && pass "--help shows usage" || fail "--help"

# Test: Basic command execution
echo "Testing basic command execution..."
output=$(./claudo -- echo "hello world")
[[ "$output" == *"hello world"* ]] && pass "basic echo" || fail "basic echo: $output"

# Test: Piped input
echo "Testing piped input..."
output=$(echo "test input" | ./claudo -- cat)
[[ "$output" == *"test input"* ]] && pass "piped input to cat" || fail "piped input: $output"

# Test: Environment variable
echo "Testing environment variable..."
output=$(./claudo -e TEST_VAR=myvalue -- printenv TEST_VAR)
[[ "$output" == *"myvalue"* ]] && pass "-e sets env var" || fail "-e env var: $output"

# Test: Multiple environment variables
echo "Testing multiple environment variables..."
output=$(./claudo -e VAR1=one -e VAR2=two -- sh -c 'echo $VAR1 $VAR2')
[[ "$output" == *"one two"* ]] && pass "multiple -e flags" || fail "multiple -e: $output"

# Test: Working directory is mounted
echo "Testing working directory mount..."
output=$(./claudo -- pwd)
dir_name=$(basename "$(pwd)")
[[ "$output" == *"/workspaces/$dir_name"* ]] && pass "workdir is /workspaces/<dirname>" || fail "workdir: $output"

# Test: Current directory files are accessible
echo "Testing current directory is mounted..."
output=$(./claudo -- ls)
[[ "$output" == *"claudo"* ]] && pass "current dir files visible" || fail "current dir: $output"

# Test: Directory with colon is rejected
echo "Testing directory with colon is rejected..."
tmpdir=$(mktemp -d)
colondir="$tmpdir/test:colon"
mkdir -p "$colondir"
output=$(cd "$colondir" && "$OLDPWD/claudo" -- echo "should fail" 2>&1 || true)
rm -rf "$tmpdir"
[[ "$output" == *"Directory path contains"* && "$output" == *":"* ]] && pass "colon in path rejected" || fail "colon rejection: $output"

# Test: --tmp mode (isolated)
echo "Testing --tmp mode..."
output=$(./claudo --tmp -- pwd)
[[ "$output" == *"/workspaces/tmp"* ]] && pass "--tmp sets workdir to /workspaces/tmp" || fail "--tmp workdir: $output"

# Test: --tmp mode doesn't mount current dir
echo "Testing --tmp doesn't mount current dir..."
output=$(./claudo --tmp -- ls /workspaces 2>&1 || true)
[[ "$output" != *"claudo"* ]] && pass "--tmp doesn't expose current dir" || fail "--tmp isolation: $output"

# Test: --tmp mode workdir is writable
echo "Testing --tmp workdir is writable..."
output=$(./claudo --tmp -- touch /workspaces/tmp/testfile 2>&1)
[[ -z "$output" ]] && pass "--tmp workdir is writable" || fail "--tmp writable: $output"

# Test: ~/.claude is mounted
echo "Testing ~/.claude mount..."
output=$(./claudo -- ls -la /home/claudo/.claude 2>&1 || true)
[[ "$output" != *"No such file"* ]] && pass "~/.claude is mounted" || fail "~/.claude mount: $output"

# Test: Hostname is set
echo "Testing hostname..."
output=$(./claudo -- hostname)
[[ "$output" == *"claudo"* ]] && pass "hostname is claudo" || fail "hostname: $output"

# Test: --no-sudo (no-new-privileges)
echo "Testing --no-sudo restricts privileges..."
output=$(./claudo --no-sudo -- cat /proc/self/status | grep NoNewPrivs || true)
[[ "$output" == *"1"* ]] && pass "--no-sudo sets NoNewPrivs" || fail "--no-sudo: $output"

# Test: Default allows new privileges
echo "Testing default allows privileges..."
output=$(./claudo -- cat /proc/self/status | grep NoNewPrivs || true)
[[ "$output" == *"0"* ]] && pass "default NoNewPrivs is 0" || fail "default privileges: $output"

# Test: --no-privileges drops capabilities
echo "Testing --no-privileges drops capabilities..."
output=$(./claudo --no-privileges -- cat /proc/self/status | grep CapEff || true)
[[ "$output" == *"0000000000000000"* ]] && pass "--no-privileges drops all caps" || fail "--no-privileges caps: $output"

# Test: --git mounts gitconfig
echo "Testing --git mounts gitconfig..."
if [[ -f "$HOME/.gitconfig" ]]; then
    output=$(./claudo --git -- cat /home/claudo/.gitconfig 2>&1)
    [[ "$output" != *"No such file"* ]] && pass "--git mounts .gitconfig" || fail "--git gitconfig: $output"
else
    pass "--git (skipped: no ~/.gitconfig on host)"
fi

# Test: --git gitconfig is read-only
echo "Testing --git gitconfig is read-only..."
if [[ -f "$HOME/.gitconfig" ]]; then
    output=$(./claudo --git -- sh -c 'echo test >> /home/claudo/.gitconfig' 2>&1 || true)
    [[ "$output" == *"Read-only"* || "$output" == *"read-only"* ]] && pass "--git gitconfig is read-only" || fail "--git read-only: $output"
else
    pass "--git read-only (skipped: no ~/.gitconfig on host)"
fi

# Test: --host network mode
echo "Testing --host network..."
# Just verify it doesn't error; full test would require checking network namespace
./claudo --host -- echo "host network ok" > /dev/null && pass "--host doesn't error" || fail "--host"

# Test: Named container (create and cleanup)
echo "Testing --name creates persistent container..."
./claudo -n testcontainer -- echo "named" > /dev/null
docker ps -a --format '{{.Names}}' | grep -q "claudo-testcontainer" && pass "-n creates named container" || fail "-n container"
docker rm -f claudo-testcontainer > /dev/null 2>&1

# Test: --docker-socket mounts docker socket
echo "Testing --docker-socket mounts docker socket..."
output=$(./claudo --docker-socket -- ls -la /var/run/docker.sock 2>&1 || true)
[[ "$output" == *"docker.sock"* && "$output" != *"No such file"* ]] && pass "--docker-socket mounts docker socket" || fail "--docker-socket socket: $output"

# Test: --docker-socket allows docker commands
echo "Testing --docker-socket allows docker commands..."
output=$(./claudo --docker-socket -- docker version 2>&1 || true)
[[ "$output" == *"Version"* || "$output" == *"version"* ]] && pass "--docker-socket docker works" || fail "--docker-socket docker: $output"

# Test: --dind sets privileged mode
echo "Testing --dind uses privileged mode..."
output=$(./claudo -v --dind -- echo "test" 2>&1 || true)
[[ "$output" == *"--privileged"* ]] && pass "--dind uses privileged mode" || fail "--dind privileged: $output"

# Test: --dind sets DIND_ENABLED env var
echo "Testing --dind sets DIND_ENABLED..."
output=$(./claudo --dind -- printenv DIND_ENABLED 2>&1 || true)
[[ "$output" == *"true"* ]] && pass "--dind sets DIND_ENABLED=true" || fail "--dind env: $output"

# Test: --prompt passes -p to claude
echo "Testing --prompt passes -p to claude..."
output=$(./claudo --dry-run --prompt "hello world" 2>&1)
[[ "$output" == *"claude --dangerously-skip-permissions -p hello world"* ]] && pass "--prompt passes -p" || fail "--prompt: $output"

# Test: -p is alias for --prompt
echo "Testing -p is alias for --prompt..."
output=$(./claudo --dry-run -p "test prompt" 2>&1)
[[ "$output" == *"-p test prompt"* ]] && pass "-p works" || fail "-p: $output"

# Test: zsh functions are available (via entrypoint sourcing .zshrc)
echo "Testing zsh config is loaded..."
output=$(./claudo -- zsh -c 'echo $PATH')
[[ "$output" == *".local/bin"* ]] && pass "PATH includes .local/bin" || fail "zsh PATH: $output"

echo
echo "=== All tests passed ==="
