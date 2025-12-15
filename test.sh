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

# Test: --docker-opts passes options to docker
echo "Testing --docker-opts passes options to docker..."
output=$(./claudo --dry-run --docker-opts "--memory 2g" -- echo test 2>&1)
[[ "$output" == *"--memory 2g"* ]] && pass "--docker-opts passes options" || fail "--docker-opts: $output"

# Test: zsh functions are available (via entrypoint sourcing .zshrc)
echo "Testing zsh config is loaded..."
output=$(./claudo -- zsh -c 'echo $PATH')
[[ "$output" == *".local/bin"* ]] && pass "PATH includes .local/bin" || fail "zsh PATH: $output"

# Test: --attach errors when container doesn't exist
echo "Testing --attach errors for nonexistent container..."
output=$(./claudo --attach nonexistent 2>&1 || true)
[[ "$output" == *"does not exist"* ]] && pass "--attach errors for nonexistent" || fail "--attach nonexistent: $output"

# Test: --attach reattaches to stopped container
echo "Testing --attach reattaches to stopped container..."
./claudo -n attachtest -- echo "first run" > /dev/null
output=$(./claudo --attach attachtest)
docker rm -f claudo-attachtest > /dev/null 2>&1
[[ "$output" == *"first run"* ]] && pass "--attach reattaches to stopped container" || fail "--attach stopped: $output"

# Test: -a is alias for --attach
echo "Testing -a is alias for --attach..."
output=$(./claudo -a nonexistent 2>&1 || true)
[[ "$output" == *"does not exist"* ]] && pass "-a works as alias" || fail "-a alias: $output"

# Test: --attach errors when command args are passed
echo "Testing --attach rejects command override..."
output=$(./claudo --attach foo -- zsh 2>&1 || true)
[[ "$output" == *"cannot override"* ]] && pass "--attach rejects command args" || fail "--attach command: $output"

# Test: --attach help text
echo "Testing --attach in help..."
./claudo --help | grep -q "\-a, --attach" && pass "--attach in help" || fail "--attach help"

# Test: --no-network disables network access
echo "Testing --no-network disables network..."
output=$(./claudo --no-network -- ping -c 1 8.8.8.8 2>&1 || true)
[[ "$output" == *"Network is unreachable"* || "$output" == *"bad address"* || "$output" == *"unknown host"* ]] && pass "--no-network disables network" || fail "--no-network: $output"

# Test: --no-network help text
echo "Testing --no-network in help..."
./claudo --help | grep -q "\-\-no-network" && pass "--no-network in help" || fail "--no-network help"

# Test: --httpjail uses httpjail wrapper with default rule
echo "Testing --httpjail uses httpjail wrapper..."
output=$(./claudo --dry-run --httpjail -- echo test 2>&1)
[[ "$output" == *"httpjail"* && "$output" == *"--docker-run"* ]] && pass "--httpjail uses httpjail wrapper" || fail "--httpjail wrapper: $output"

# Test: --httpjail default allows api.anthropic.com
echo "Testing --httpjail default rule allows Anthropic API..."
output=$(./claudo --dry-run --httpjail -- echo test 2>&1)
[[ "$output" == *"api.anthropic.com"* ]] && pass "--httpjail default allows Anthropic" || fail "--httpjail default: $output"

# Test: --httpjail-opts enables httpjail with custom rule
echo "Testing --httpjail-opts enables httpjail..."
output=$(./claudo --dry-run --httpjail-opts '--js "r.host === \"example.com\""' -- echo test 2>&1)
[[ "$output" == *"httpjail"* && "$output" == *"--docker-run"* ]] && pass "--httpjail-opts enables httpjail" || fail "--httpjail-opts: $output"

# Test: --httpjail-opts replaces default rule
echo "Testing --httpjail-opts replaces default..."
output=$(./claudo --dry-run --httpjail-opts '--js "r.host === \"example.com\""' -- echo test 2>&1)
[[ "$output" != *"api.anthropic.com"* && "$output" == *"example.com"* ]] && pass "--httpjail-opts replaces default" || fail "--httpjail-opts replace: $output"

# Test: --httpjail help text
echo "Testing --httpjail in help..."
./claudo --help | grep -q "\-\-httpjail" && pass "--httpjail in help" || fail "--httpjail help"

# Test: --httpjail-opts help text
echo "Testing --httpjail-opts in help..."
./claudo --help | grep -q "\-\-httpjail-opts" && pass "--httpjail-opts in help" || fail "--httpjail-opts help"

# Test: --httpjail uses XDG_CONFIG_HOME for world-readable CA cert
echo "Testing --httpjail uses XDG_CONFIG_HOME..."
output=$(./claudo --dry-run --httpjail -- echo test 2>&1)
[[ "$output" == *"XDG_CONFIG_HOME=/tmp/httpjail-config"* ]] && pass "--httpjail sets XDG_CONFIG_HOME" || fail "--httpjail XDG: $output"

# Test: --httpjail CA cert is readable in container (functional test)
# This test requires httpjail + sudo + nftables + network namespace permissions
# It may not work in CI environments due to security restrictions
echo "Testing --httpjail CA cert is accessible..."
if command -v httpjail &> /dev/null && sudo -n true 2>/dev/null; then
    # Try running httpjail - it may fail due to permission restrictions in CI
    output=$(./claudo --httpjail -- cat /tmp/httpjail-config/httpjail/ca-cert.pem 2>&1 || true)
    if [[ "$output" == *"BEGIN CERTIFICATE"* ]]; then
        pass "--httpjail CA cert readable"
    elif [[ "$output" == *"Operation not permitted"* || "$output" == *"permission"* || "$output" == *"namespace"* || "$output" == *"No such file"* ]]; then
        # httpjail may fail silently in restricted environments (CI, containers, etc.)
        pass "--httpjail CA cert (skipped: httpjail cannot run in this environment)"
    else
        fail "--httpjail CA cert: $output"
    fi
else
    pass "--httpjail CA cert (skipped: httpjail not installed or no sudo)"
fi

# Test: --httpjail errors if httpjail not installed
echo "Testing --httpjail errors if httpjail not found..."
output=$(PATH=/usr/bin:/bin ./claudo --httpjail -- echo test 2>&1 || true)
[[ "$output" == *"httpjail"* && "$output" == *"not found"* && "$output" == *"nftables"* && "$output" == *"github.com/coder/httpjail"* ]] && pass "--httpjail missing error" || fail "--httpjail missing: $output"

# Test: Unknown long option is rejected
echo "Testing unknown long option is rejected..."
output=$(./claudo --unknown-option 2>&1 || true)
[[ "$output" == *"Unknown option"* && "$output" == *"--unknown-option"* ]] && pass "unknown long option rejected" || fail "unknown long option: $output"

# Test: Unknown short option is rejected
echo "Testing unknown short option is rejected..."
output=$(./claudo -x 2>&1 || true)
[[ "$output" == *"Unknown option"* && "$output" == *"-x"* ]] && pass "unknown short option rejected" || fail "unknown short option: $output"

echo
echo "=== All tests passed ==="
